#!/usr/bin/env ruby
# frozen_string_literal: true

# Synchronize only framework products emitted by make_frameworks.py.
# This intentionally does not create targets, phases, dependencies, or groups.
require "xcodeproj"
require "pathname"
require "set"

REPO_ROOT = Pathname.new(__dir__).parent.realpath
PROJECT_PATH = REPO_ROOT.join("Pyto.xcodeproj")
EXTENSIONS_ROOT = REPO_ROOT.join("Extensions").realpath

project = Xcodeproj::Project.open(PROJECT_PATH.to_s)
generated_groups = Set.new
preserved_frameworks = Hash.new { |hash, group| hash[group] = Set.new }
Dir.glob(REPO_ROOT.join("Extensions/Dependencies/tools/build-*.sh").to_s).each do |script|
  File.read(script).scan(/make_frameworks\.py["']?\s+\S+\s+(\w+)([^\n]*)/).each do |group, extra|
    generated_groups.add(group)
    extra.split.select { |name| name.match?(/\A[\w-]+\z/) }.each do |name|
      preserved_frameworks[group].add("#{name}.framework")
    end
  end
end
abort "Cannot discover generated framework groups" if generated_groups.length < 20

# Return the on-disk framework directory for a PBXGroup only when it is exactly
# an Extensions/<group> directory.  Other groups (including Dependencies) are
# deliberately out of scope.
def extensions_group_path(group, extensions_root)
  # Do not call realpath: build outputs may not exist until the preceding
  # build-* script runs.  The PBXGroup's resolved lexical path is the source
  # of truth for selecting Extensions/<group>.
  path = Pathname.new(group.real_path.to_s).cleanpath
  return nil unless path.dirname == extensions_root

  path
end

def framework_name(file_ref)
  (file_ref.path || file_ref.name).to_s
end

def deep_copy(value)
  case value
  when Hash
    value.each_with_object({}) { |(key, item), copy| copy[key] = deep_copy(item) }
  when Array
    value.map { |item| deep_copy(item) }
  else
    value
  end
end

def phase_for_file_ref(project, file_ref)
  project.targets.flat_map do |target|
    target.build_phases.map do |phase|
      next unless phase.respond_to?(:files)
      build_file = phase.files.find { |candidate| candidate.file_ref == file_ref }
      build_file ? [phase, build_file] : nil
    end.compact
  end
end

def add_build_file_with_settings(project, phase, file_ref, settings)
  build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
  build_file.file_ref = file_ref
  build_file.settings = deep_copy(settings) unless settings.nil?
  phase.files << build_file
  build_file
end

# Do this before changing the project.  Missing _ast3 is a compile error and
# must not be hidden by a best-effort synchronization (and _ast27 is required
# alongside it).
typed_ast_dir = EXTENSIONS_ROOT.join("TypedAST")
required_typed_ast = %w[typed_ast-_ast3.framework typed_ast-_ast27.framework]
missing_typed_ast = required_typed_ast.reject { |name| typed_ast_dir.join(name).directory? }
unless missing_typed_ast.empty?
  abort "TypedAST source products missing; refusing to sync: #{missing_typed_ast.join(', ')}"
end

synced = []
project.objects.grep(Xcodeproj::Project::Object::PBXGroup).each do |group|
  directory = extensions_group_path(group, EXTENSIONS_ROOT)
  next unless directory && generated_groups.include?(directory.basename.to_s)

  expected_paths = Dir.glob(directory.join("*.framework").to_s).sort.map { |path| Pathname.new(path) }
  expected_names = expected_paths.map { |path| path.basename.to_s }.to_set
  framework_refs = group.files.select { |ref| framework_name(ref).end_with?(".framework") }
  next if framework_refs.empty? && expected_paths.empty?

  # Capture phase/settings templates before removing stale refs.  Each phase
  # gets its own settings, so link/embed/code-sign attributes are preserved.
  phase_templates = Hash.new { |hash, phase| hash[phase] = [] }
  framework_refs.each do |file_ref|
    # Preserved SciPy runtime/dependency dylibs are linkable frameworks, not
    # templates for the dynamically loaded Python extension bundles.
    next if preserved_frameworks[directory.basename.to_s].include?(framework_name(file_ref))
    phase_for_file_ref(project, file_ref).each do |phase, build_file|
      phase_templates[phase] << deep_copy(build_file.settings)
    end
  end

  framework_refs.each do |file_ref|
    next if expected_names.include?(framework_name(file_ref))

    phase_for_file_ref(project, file_ref).each do |phase, build_file|
      phase.files.delete(build_file)
      build_file.remove_from_project
    end
    group.children.delete(file_ref)
    file_ref.remove_from_project
  end

  existing = group.files.each_with_object({}) do |file_ref, result|
    result[framework_name(file_ref)] = file_ref if framework_name(file_ref).end_with?(".framework")
  end

  expected_paths.each do |path|
    name = path.basename.to_s
    # Existing references already have the intended per-target link/embed
    # membership. Only genuinely new products need a phase template.
    next if existing.key?(name)
    file_ref = group.new_file(name)
    existing[name] = file_ref

    phase_templates.each do |phase, settings_list|
      next if phase.files.any? { |build_file| build_file.file_ref == file_ref }

      # Normally there is one template per phase.  If the project contains
      # multiple same-group entries, retain each phase's first exact settings.
      settings = settings_list.first
      add_build_file_with_settings(project, phase, file_ref, settings)
    end
  end

  synced << "#{group.hierarchy_path} (#{expected_paths.length} frameworks)"
end

# The pinned NumPy source links quicksort/mergesort objects directly into
# _multiarray_umath. It no longer emits the historical separate libnpysort.a.
# Remove only that obsolete reference, and only after verifying sorting code
# is present in the actual generated binary. Keep libnpymath.a unchanged.
unless EXTENSIONS_ROOT.join("NumPy/libnpysort.a").file?
  binaries = Dir.glob(EXTENSIONS_ROOT.join("NumPy/numpy-core-_multiarray_umath.framework/*.so").to_s)
  abort "Cannot verify NumPy sorting implementation" unless binaries.length == 1
  symbols = IO.popen(["xcrun", "nm", binaries.first], &:read)
  abort "NumPy sorting symbols are missing" unless $?.success? && symbols.match?(/quicksort|mergesort|timsort/)
  project.objects.grep(Xcodeproj::Project::Object::PBXFileReference).each do |ref|
    next unless ref.path == "libnpysort.a" && Pathname.new(ref.real_path.to_s).cleanpath == EXTENSIONS_ROOT.join("NumPy/libnpysort.a")
    phase_for_file_ref(project, ref).each do |phase, build_file|
      phase.files.delete(build_file)
      build_file.remove_from_project
    end
    ref.remove_from_project
  end
  puts "Verified NumPy sorting code in _multiarray_umath; removed obsolete libnpysort.a reference"
end

project.save
puts "Synchronized #{synced.length} Extensions framework group(s):"
puts synced.map { |line| "- #{line}" }
