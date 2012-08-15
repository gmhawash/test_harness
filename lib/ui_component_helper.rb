class TestHarness
  module UIComponentHelper
    def component
      self.class.parent.component
    end

    # If the UIComponent is sent a message it does not understand, it will
    # forward that message on to its {#browser} but wrap the call in a block
    # provided to the the browser's `#within` method. This provides convenient
    # access to the browser driver's DSL, automatically scoped to this
    # component.
    def method_missing(name, *args, &block)
      if respond_to?(name)
        browser.within(component.within) do
          browser.send(name, *args, &block)
        end
      else
        super
      end
    end

    # Since Kernel#select is defined, we have to override it specifically here.
    def select(*args, &block)
      browser.within(component.within) do
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

    def component_path
      component.path.gsub(/:\w+/) {|match| mm.subject.send(match.tr(':',''))}
    end

    def submit!
      form_hash.each do |k,v|
        fill_in k.to_s, :with => v
      end

      if has_css?(locator = component.submit)
        find(:css, component.submit).click
      else
        click_on component.submit
      end
    end

    def form_hash
      form.instance_variable_get("@table")
    end

    def form
      @form ||= OpenStruct.new
    end

    private
    # @private
    # (Not really private, but YARD seemingly lacks RDoc's :nodoc tag, and the
    # semantics here don't differ from Object#respond_to?)
    def respond_to?(name)
      super || browser.respond_to?(name)
    end

    def server_host
      configuration.server_host || Capybara.default_host || 'http://example.com'
    end
  end
end
