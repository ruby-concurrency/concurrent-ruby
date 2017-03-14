module Concurrent

  # A submodule for unstable, highly experimental features that are likely to
  # change often and which may never become part of the core gem. Also for
  # new, experimental version of abstractions already in the core gem.
  #
  # Most new features should start in this module, clearly indicating the
  # experimental and unstable nature of the feature. Once a feature becomes
  # more stable and is a candidate for inclusion in the core gem it should
  # be moved up to the `Concurrent` module, where it would reside once merged
  # into the core gem.
  #
  # The only exception to this is for features which *replace* features from
  # the core gem in ways that are breaking and not backward compatible. These
  # features should remain in this module until merged into the core gem. This
  # will prevent namespace collisions.
  #
  # @!macro [attach] edge_warning
  #   @api Edge
  #   @note **Edge Features** are under active development and may change frequently.
  #
  #     -   Deprecations are not added before incompatible changes.
  #     -   Edge version: _major_ is always 0, _minor_ bump means incompatible change,
  #         _patch_ bump means compatible change.
  #     -   Edge features may also lack tests and documentation.
  #     -   Features developed in `concurrent-ruby-edge` are expected to move
  #         to `concurrent-ruby` when finalised.
  module Edge
  end
end
