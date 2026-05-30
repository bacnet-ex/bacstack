%Doctor.Config{
  ignore_modules: [
    ~r"^Mix\.Tasks\.",
    # ObjectsMacro defines a large number of methods inside `quote do` blocks
    # that get injected into generated object modules. Doctor has a known
    # limitation (bug) correctly associating @spec on functions defined inside
    # such quote blocks for coverage calculation. We have manually ensured
    # proper @spec on all public and private functions where feasible.
    # https://github.com/akoutmos/doctor/issues/69
    # TODO: Remove once bug fixed
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
