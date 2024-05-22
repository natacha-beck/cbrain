
#
# NeuroHub Project
#
# Copyright (C) 2021
# The Royal Institution for the Advancement of Learning
# McGill University
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# Helper for logging in using Keycloak identity stuff
module KeycloakHelpers

    Revision_info=CbrainFileRevision[__FILE__] #:nodoc:

    # KEYCLOAK authentication URL constants
    # Maybe should be made configurable.
    KEYCLOAK_AUTHORIZE_URI = "http://localhost:8080/realms/lasso-realm/protocol/openid-connect/auth" # will be issued a GET with params
    KEYCLOAK_TOKEN_URI     = "keycloak:8080/realms/lasso-realm/protocol/openid-connect/token"     # will be issued a POST with a single code
    KEYCLOAK_LOGOUT_URI    = "http://localhost:8080/realms/lasso-realm/protocol/openid-connect/logout"       # for pages that provide this link

    # Returns the URI to send users to the KEYCLOAK authentication page.
    # The parameter keycloak_action_url should be the URL to the controller
    # action here in CBRAIN that will received the POST response.
    def keycloak_login_uri(keycloak_action_url)
      return nil if     api_request?
      return nil unless keycloak_auth_configured?

      # Create the URI to authenticate with KEYCLOAK
      keycloak_params = {
        :client_id     => keycloak_client_id,
        :response_type => 'code',
        :scope         => "openid email profile",
        :redirect_uri  => keycloak_action_url, # generated from Rails routes
        :state         => keycloak_current_state, # method is below
      }
      KEYCLOAK_AUTHORIZE_URI + '?' + keycloak_params.to_query
    end

    def keycloak_logout_uri
      KEYCLOAK_LOGOUT_URI
    end

    def keycloak_fetch_token(code, keycloak_action_url)
        # Query Keycloak; this returns all the info we need at the same time.
        auth_header = keycloak_basic_auth_header # method is below

        response = Typhoeus.post(KEYCLOAK_TOKEN_URI,
          :body   => {
                       :code          => code,
                       :redirect_uri  => keycloak_action_url,
                       :grant_type    => 'authorization_code',
                     },
          :headers => { :Accept       => 'application/json',
                        :Authorization => auth_header,
                      }
        )

        # Parse the response
        body         = response.response_body
        json         = JSON.parse(body)
        jwt_id_token = json["id_token"]
        identity_struct, _ = JWT.decode(jwt_id_token, nil, false)

        return identity_struct
      rescue => ex
        Rails.logger.error "KEYCLOAK token request failed: #{ex.class} #{ex.message}"
        return nil
      end

      # Returns the value for the Authorization header
      # when doing the client authentication.
      #
      #  "Basic 1745djfuebwifh37236djdf74.etc.etc"
      def keycloak_basic_auth_header
        client_id     = keycloak_client_id
        client_secret = keycloak_client_secret
        "Basic " + Base64.strict_encode64("#{client_id}:#{client_secret}")
      end

      # Returns a string that should stay constants during the entire
      # keycloak negotiations. The current Rails session_id, encoded, will do
      # the trick. The Rails session is maintained by a cookie already
      # created and maintained, at this point.
      def keycloak_current_state
        Digest::MD5.hexdigest( request.session_options[:id] )
      end

      # Return the registered keycloak endpoint client ID.
      # This value must be configured by the CBRAIN admin
      # in the meta data of the portal. Returns nil if unset.
      def keycloak_client_id
        myself = RemoteResource.current_resource
        myself.meta[:keycloak_client_id].presence.try(:strip)
      end

      # Return the registered keycloak endpoint client secret.
      # This value must be configured by the CBRAIN admin
      # in the meta data of the portal. Returns nil if unset.
      def keycloak_client_secret
        myself = RemoteResource.current_resource
        myself.meta[:keycloak_client_secret].presence.try(:strip)
      end

      # Returns true if the CBRAIN system is configured for
      # keycloak auth.
      def keycloak_auth_configured?
        myself   = RemoteResource.current_resource
        site_uri = myself.site_url_prefix.presence
        # Three conditions: site uri, client ID, client secret.
        return false if ! site_uri
        return false if ! keycloak_client_id
        return false if ! keycloak_client_secret
        true
      end

        # Record the keycloak identity for the current user.
  # (This maybe should be made into a User model method)
  def record_keycloak_identity(user, keycloak_identity)

    # In the case where a user must auth with a specific set of
    # keycloak providers, we find the first identity that
    # matches a name of that set.
    identity = set_of_identities(keycloak_identity).detect do |idstruct|
       user_can_link_to_keycloak_identity?(user, idstruct)
    end

    provider_id   = identity['aud']                || cb_error("Keycloak: No identity provider")
    provider_name = identity['azp']                || cb_error("Keycloak: No identity provider name")
    pref_username = identity['preferred_username'] ||
                    identity['name']               || cb_error("Keycloak: No preferred username")

    # Special case for ORCID, because we already have fields for that provider
    # We do NOT do this in the case where the user is forced to auth with keycloak.
    if provider_name == 'ORCID' && ! user_must_link_to_keycloak?(user)
      orcid = pref_username.sub(/@.*/, "")
      user.meta['orcid'] = orcid
      user.addlog("Linked to ORCID identity: '#{orcid}' through Keycloak")
      return
    end

    user.meta[:keycloak_provider_id]        = provider_id
    user.meta[:keycloak_provider_name]      = provider_name # used in show page
    user.meta[:keycloak_preferred_username] = pref_username
    user.addlog("Linked to Keycloak identity: '#{pref_username}' on provider '#{provider_name}'")
  end

  # Removes the recorded keycloak identity for +user+
  def unlink_keycloak_identity(user)
    user.meta[:keycloak_provider_id]        = nil
    user.meta[:keycloak_provider_name]      = nil
    user.meta[:keycloak_preferred_username] = nil
    user.addlog("Unlinked Keycloak identity")
  end

  def set_of_identities(keycloak_identity)
    keycloak_identity['identity_set'] || [ keycloak_identity ]
  end

  def set_of_identity_provider_names(keycloak_identity)
    set_of_identities(keycloak_identity).map { |s| s['azp'] }
  end

  # Returns an array of allowed identity provider names.
  # Returns nil if they are all allowed
  def allowed_keycloak_provider_names(user)
    user.meta[:allowed_keycloak_provider_names]
       .presence
      &.split(/\s*,\s*/)
      &.map(&:strip)
  end

  def user_can_link_to_keycloak_identity?(user, identity)
    allowed = allowed_keycloak_provider_names(user)
    return true if allowed.nil?
    return true if allowed.size == 1 && allowed[0] == '*'
    prov_names = set_of_identity_provider_names(identity)
    return true if (allowed & prov_names).present? # if the intersection is not empty
    false
  end

  def user_has_link_to_keycloak?(user)
    user.meta[:keycloak_provider_id].present?       &&
    user.meta[:keycloak_provider_name].present?     &&
    user.meta[:keycloak_preferred_username].present?
  end

  def user_must_link_to_keycloak?(user)
    user.meta[:allowed_keycloak_provider_names].present?
  end


  def wipe_user_password_after_keycloak_link(user)
    user.update_attribute(:crypted_password, 'Wiped-By-Keycloak-Link-' + User.random_string)
    user.update_attribute(:salt            , 'Wiped-By-Keycloak-Link-' + User.random_string)
    user.update_attribute(:password_reset  , false)
  end

  # Given a keycloak identity structure, find the user that matches it.
  # Returns the user object if found; returns a string error message otherwise.
  def find_user_with_keycloak_identity(keycloak_identity)

    provider_name = keycloak_identity['azp']
    pref_username = keycloak_identity['preferred_username'] || keycloak_identity['name']

    id_set = set_of_identities(keycloak_identity) # a keycloak record can contain several identities

    # For each present identity, find all users that have it.
    # We only allow ONE cbrain user to link to any of the identities.
    users = id_set.inject([]) do |ulist, subident|
      ulist |= find_users_with_specific_identity(subident)
    end

    if users.size == 0
      Rails.logger.error "KEYCLOAK warning: no CBRAIN accounts found for identity '#{pref_username}' on provider '#{provider_name}'"
      return "No CBRAIN user matches your Keycloak identity. Create a CBRAIN account or link your existing CBRAIN account to your Keycloak provider."
    end

    if users.size > 1
      loginnames = users.map(&:login).join(", ")
      Rails.logger.error "KEYCLOAK error: multiple CBRAIN accounts (#{loginnames}) found for identity '#{pref_username}' on provider '#{provider_name}'"
      return "Several CBRAIN user accounts match your Keycloak identity. Please contact the CBRAIN admins."
    end

    # The one lucky user
    return users.first
  end

  # Returns an array of all users that have linked their
  # account to the +identity+ provider. The array can
  # be empty (no such users) or contain more than one
  # user (an account management error).
  def find_users_with_specific_identity(identity)
    provider_id   = identity['aud']                || cb_error("Keycloak: No identity provider")
    provider_name = identity['azp']                || cb_error("Keycloak: No identity provider name")
    pref_username = identity['preferred_username'] ||
                    identity['name']               || cb_error("Keycloak: No preferred username")

    # Special case for ORCID, because we already have fields for that provider
    if provider_name == 'ORCID'
      orcid = pref_username.sub(/@.*/, "")
      users = User.find_all_by_meta_data(:orcid, orcid).to_a
      return users if users.present?
      # otherwise we fall through to detect users who linked with ORCID through Keycloak
    end

    # All other keycloak providers
    # We need a user which match both the preferred username and provider_id
    users = User.find_all_by_meta_data(:keycloak_preferred_username, pref_username)
      .to_a
      .select { |user| user.meta[:keycloak_provider_id] == provider_id }
  end

end