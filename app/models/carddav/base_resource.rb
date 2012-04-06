module Carddav
  class BaseResource < DAV4Rack::Resource
    # On the subclass define a similar hash for properties specific to that
    # subclass, and another hash for properties specific to that subclass that
    # should not be returned in an allprop request.
    # Properties defined here may be implemented in the subclass, but do not
    # need to be defined there
    BASE_PROPERTIES = {
      'DAV:' => %w(
        creationdate
        current-user-principal
        displayname
        getcontentlength
        getcontenttype
        getetag
        getlastmodified
        group
        owner
        principal-URL
        resourcetype
      ),
      # Define this here as an empty array so it will fall through to dav4rack
      # and they'll return a NotImplemented instead of BadRequest
      'urn:ietf:params:xml:ns:carddav' => []
      }

    # Make OSX's AddressBook.app happy :(
    def setup
      @propstat_relative_path = true
      @root_xml_attributes = {
        'xmlns:C' => 'urn:ietf:params:xml:ns:carddav', 
        'xmlns:APPLE1' => 'http://calendarserver.org/ns/'
      }
    end

    def warden
      request.env['warden']
    end

    def current_user
      @current_user ||= warden.authenticate(:scope => :user)
      @current_user
    end

    def is_self?(other_path)
      ary = [@public_path]
      ary.push(@public_path+'/') if @public_path[-1] != '/'
      ary.push(@public_path[0..-2]) if @public_path[-1] == '/'
      ary.include? other_path
    end

    def get_property(element)
      Rails.logger.error "Base::get_book_property(#{element})"

      name = element[:name]
      namespace = element[:ns_href]

      begin
        our_properties = BaseResource.merge_properties(BASE_PROPERTIES, self.class::ALL_PROPERTIES)
        our_properties = BaseResource.merge_properties(our_properties, self.class::EXPLICIT_PROPERTIES)
      rescue
        # Just in case we don't have any properties defined on the subclass
        our_properties = BASE_PROPERTIES
      end

      unless our_properties.include? namespace
        raise BadRequest
      end

      fn = name.underscore

      if our_properties[namespace].include?(name)
        # The base dav4rack handler will use nicer looking function names for some properties
        # Let's just humor it.
        return self.send(fn.to_sym) if self.respond_to?(fn)
      end

      super(element)
    end

    # Some properties shouldn't be included in an allprop request
    # but it's nice to do some sanity checking so keeping a list is good
    def properties
      BaseResource::merge_properties(BASE_PROPERTIES, self.class::ALL_PROPERTIES)
    end

    # Properties in alphabetical order
    # Properties need to be protected so that dav4rack doesn't alias them away
    protected

    # This violates the spec that requires an HTTP or HTTPS URL.  Unfortunately,
    # Apple's AddressBook.app treats everything as a pathname.  Also, the model
    # shouldn't need to know about the URL scheme and such.
    def current_user_principal
      s="<D:current-user-principal xmlns:D='DAV:'><D:href>/carddav/</D:href></D:current-user-principal>"
      Nokogiri::XML::DocumentFragment.parse(s)
    end

    def group
    end

    def owner
      s="<D:owner xmlns:D='DAV:'><D:href>/carddav/</D:href></D:owner>"
      Nokogiri::XML::DocumentFragment.parse(s)
    end

    def principal_url
      s="<D:principal-URL xmlns:D='DAV:'><D:href>/carddav/</D:href></D:principal-URL>"
      Nokogiri::XML::DocumentFragment.parse(s)
    end

    # This is not a property.
    protected
    def self.merge_properties(all, explicit)
      ret = all.dup
      explicit.each do |key, value|
        ret[key] ||= []
        ret[key] += value
        ret[key].uniq!
      end
      ret
    end

  end
end