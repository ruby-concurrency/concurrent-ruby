Atomic = Rubinius::AtomicReference

require 'atomic/direct_update'

# define additional aliases
class Atomic
  alias value get
  alias value= set
  alias compare_and_swap compare_and_set
  alias swap get_and_set
end