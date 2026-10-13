%Doctor.Config{
  ignore_modules: [
    ~r"^Mix\.Tasks\.",
    # ObjectsMacro still injects object-module functions inside `quote do`.
    # Doctor cannot associate @spec/@doc on functions defined in those quotes
    # and reports them as missing coverage on this module.
    # https://github.com/akoutmos/doctor/issues/69
    BACnet.Protocol.ObjectsMacro
  ],
  ignore_paths: [~r/test\//],
  min_module_doc_coverage: 80,
  min_module_spec_coverage: 100,
  min_overall_doc_coverage: 80,
  min_overall_moduledoc_coverage: 100,
  min_overall_spec_coverage: 100,
  exception_moduledoc_required: true,
  raise: false,
  reporter: Doctor.Reporters.Full,
  struct_type_spec_required: true,
  umbrella: false,
  failed: false
}
