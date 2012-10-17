require 'test_helper'
class TestHarness
  class Given
    include TestHarness::TestHelper

    Dir.glob(Rails.root.join(TestHarness.autoload_path, 'given/*.rb')).each do |file|
      component =  File.basename(file, '.rb')
      require Rails.root.join(TestHarness.autoload_path, 'given', component)
      klass = ("TestHarness::Given::%s" % File.basename(file, '.rb').camelize).constantize
      include klass
    end
  end
end


