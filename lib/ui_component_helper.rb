class MissingConfiguration < Exception; end

class TestHarness
  module UIComponentHelper
    def mm
      TestHarness.mm
    end

    def component
      parent_class = TestHarness::Utilities.get_parent_class(self.class)
      parent_class ? parent_class.component : nil
    end

    def reset
      @form = nil
    end

    def configuration
      TestHarness.configuration
    end

    def browser
      @browser ||= begin
        raise MissingConfiguration.new('TestHarness.browser must be defined') if configuration.browser.nil?
        configuration.browser
       end
    end

    # If the UIComponent is sent a message it does not understand, it will
    # forward that message on to its {#browser} but wrap the call in a block
    # provided to the the browser's `#within` method. This provides convenient
    # access to the browser driver's DSL, automatically scoped to this
    # component.
    def method_missing(name, *args, &block)
      if respond_to?(name)
        if component.within
          browser.within(component.within) do
            browser.send(name, *args, &block)
          end
        else
          browser.send(name, *args, &block)
        end
      else
        super
      end
    end

    def wait_for_ajax
      start_time = Time.now
      until page.evaluate_script('jQuery.isReady&&jQuery.active==0') or (start_time + ajax_timeout) < Time.now do
        sleep 1
      end

      return unless block_given?

      # Now try to get the list of data few times until we either fail or timeout (2 seconds)
      20.times.each do |index|
        begin
          return true if yield
        rescue Exception => e
          sleep 0.5
        end
      end
      false
    end

    # Since Kernel#select is defined, we have to override it specifically here.
    def select(*args, &block)
      if component.within
        browser.within(component.within) do
          browser.select(*args, &block)
        end
      else
        browser.select(*args, &block)
      end
    end

    # We don't want to go through the method_missing above for visit, but go
    # directly to the browser object
    def visit(path)
      path = "%s:%s%s" % [server_host, Capybara.server_port, path] if path !~ /^http/

      browser.visit(path)
    end

    def show!
      visit component_path
    end

    # Used to submit elements set by the *form* method
    # In the UIDriver, you can use:
    #   form.username = 'user@email.com'
    #   form.password = 'password'
    #   form.yes = true    # for checkbox
    #   form.radio1 = true # for radio button
    #
    #   submit!
    #
    def submit!
      if has_css?(locator = component.submit)
        find(:css, component.submit).click
      else
        click_on component.submit
      end
    end

    # Used to set form elements for submittal by the method submit!
    # In the UIDriver, you can use:
    #   form.username = 'user@email.com'
    #   form.password = 'password'
    #   submit!
    def form
      @form ||= TestHarness::FormStruct.new(browser)
    end

    private
    def form_hash
      form.instance_variable_get("@table") || {}
    end

    private
    def component_path
      case path = component.path
      when Proc then path.call(mm)
      else
        path.gsub(/:\w+/) do |match|
          token = match.tr(':', '')
          if mm.subject.is_a? Hash
            mm.subject.with_indifferent_access[token]
          elsif mm.subject.respond_to? token.to_sym
            mm.subject.send(token)
          elsif mm.respond_to? token.to_sym
            mm.send(token)
          elsif mm.respond_to? token.tr('_id', '')
            mm.send(token.tr('_id', '')).id
          end
        end
      end
    end

    # @private
    # (Not really private, but YARD seemingly lacks RDoc's :nodoc tag, and the
    # semantics here don't differ from Object#respond_to?)
    def respond_to?(name)
      super || browser.respond_to?(name)
    end

    def server_host
      configuration.server_host || Capybara.default_host || 'http://example.com'
    end

    def ajax_timeout
      (configuration.ajax_timeout || 5).to_i.seconds
    end
  end
end
