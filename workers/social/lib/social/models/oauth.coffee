bongo       = require 'bongo'
{ secure, signature } = bongo
crypto      = require 'crypto'
oauth       = require 'oauth'
parser      = require 'url'
KodingError = require '../error'


module.exports = class OAuth extends bongo.Base

  @share()

  @set
    sharedMethods   :
      static        :
        getUrl      : (signature Object, Function)

  NOTSUPPORTEDERR = new KodingError 'OAuth provider is not supported'

  @PROVIDERS =

    # -- GITLAB PROVIDER --------------------------------------------------8<--

    gitlab    :
      title   : 'GitLab OAuth Provider'
      enabled : true
      getUrl  : (client, urlOptions, callback) ->

        checkGroupGitLabSettings = (client, callback) ->

          { sessionToken: clientId, context: { group: slug } } = client

          JSession = require './session'
          JSession.one { clientId }, (err, session) ->
            return callback err  if err
            return callback new KodingError 'Session invalid'  unless session

            JGroup = require './group'
            JGroup.one { slug }, (err, group) ->

              if not err and group and group.config?.gitlab?.enabled

                settings = {
                  url: group.config.gitlab.url
                  applicationId: group.config.gitlab.applicationId
                  state: session._id
                }

                callback null, settings

              else

                callback new KodingError 'Integration is not enabled'

        { returnUrl, redirectUri } = urlOptions
        { applicationId, host, port } = KONFIG.gitlab
        host ?= 'gitlab.com'
        protocol = '//'
        port = if port then ":#{port}" else ''
        host = urlOptions.host ? host
        redirectUri = "#{redirectUri}?returnUrl=#{returnUrl}"  if returnUrl

        checkGroupGitLabSettings client, (err, data) ->
          return callback err  if err

          url = "#{protocol}#{host}#{port}"
          { url, applicationId, state } = data  if data

          state = "&state=#{state}"
          url   = "#{url}/oauth/authorize?"
          url  += "client_id=#{applicationId}&"
          url  += "response_type=code#{state}&"
          url  += "redirect_uri=#{redirectUri}"

          callback null, url


    # -- GITHUB PROVIDER --------------------------------------------------8<--

    github    :
      title   : 'Github OAuth Provider'
      enabled : false
      getUrl  : (client, urlOptions, callback) ->

        { clientId } = KONFIG.github
        { scope, returnUrl } = urlOptions
        scope = 'user:email'  unless scope
        redirectUri = "#{redirectUri}?returnUrl=#{returnUrl}"  if returnUrl

        url  = "https://github.com/login/oauth/authorize?"
        url += "client_id=#{clientId}&"
        url += "scope=#{scope}&redirect_uri=#{redirectUri}"

        callback null, url


    # -- FACEBOOK PROVIDER ------------------------------------------------8<--

    facebook  :
      title   : 'Facebook OAuth Provider'
      enabled : false
      getUrl  : (client, urlOptions, callback) ->

        { clientId } = KONFIG.facebook
        { redirectUri } = urlOptions

        url  = "https://facebook.com/dialog/oauth?"
        url += "client_id=#{clientId}&"
        url += "redirect_uri=#{redirectUri}&scope=email"

        callback null, url


    # -- GOOGLE PROVIDER --------------------------------------------------8<--

    google    :
      title   : 'Google OAuth Provider'
      enabled : false
      getUrl  : (client, urlOptions, callback) ->

        { client_id } = KONFIG.google
        { redirectUri } = urlOptions

        JSession = require './session'
        JSession.one { clientId: client.sessionToken }, (err, session) ->
          return callback err  if err

          state = session._id
          url  = 'https://accounts.google.com/o/oauth2/auth?'
          url += 'scope=https://www.google.com/m8/feeds '
          url += 'https://www.googleapis.com/auth/userinfo.profile '
          url += 'https://www.googleapis.com/auth/userinfo.email&'
          url += "redirect_uri=#{redirectUri}&"
          url += 'response_type=code&'
          url += "client_id=#{client_id}&"
          url += "state=#{state}&"
          url += 'access_type=offline'

          callback null, url


    # -- LINKEDIN PROVIDER ------------------------------------------------8<--

    linkedin  :
      title   : 'LinkedIn OAuth Provider'
      enabled : false
      getUrl  : (client, urlOptions, callback) ->

        { client_id } = KONFIG.linkedin
        { redirectUri } = urlOptions

        state = crypto.createHash('md5')
          .update((new Date).toString())
          .digest('hex')

        url  = 'https://www.linkedin.com/uas/oauth2/authorization?'
        url += 'response_type=code&'
        url += "client_id=#{client_id}&"
        url += "state=#{state}&"
        url += "redirect_uri=#{redirectUri}"

        callback null, url


  @getUrl = secure (client, urlOptions, callback) ->

    { provider } = urlOptions

    if _provider = @PROVIDER[provider] and _provider.enabled
      { context: { group } } = client
      urlOptions.redirectUri = \
        "http://#{group}.#{KONFIG.hostname}/-/oauth/#{provider}/callback"
      _provider.getUrl client, urlOptions, callback
    else
      callback NOTSUPPORTEDERR


  @prependGroupName = (url, groupName) ->
    return url  if groupName is 'koding'

    url = parser.parse url

    return "#{url.protocol}//#{groupName}.#{url.host}#{url.path}"


  @saveTokensAndReturnUrl = (client, provider, callback) ->
    @getTokens provider, (err, data) =>
      return callback err  if err
      { requestToken, requestTokenSecret, url } = data

      credentials = { requestToken, requestTokenSecret }
      @saveTokens client, provider, credentials, (err) ->
        callback err, url


  @getTokens = (provider, callback) ->
    {
      key
      secret
      request_url
      access_url
      version
      redirect_uri
      signature
      secret_url
    }      = KONFIG[provider]

    client = new oauth.OAuth request_url, access_url, key, secret, version,
      redirect_uri, signature

    client.getOAuthRequestToken (err, token, tokenSecret, results) ->
      return callback err  if err

      tokenizedUrl = secret_url + token
      callback null, {
        requestToken       : token
        requestTokenSecret : tokenSecret
        url                : tokenizedUrl
      }


  @saveTokens = (client, provider, credentials, callback) ->
    JSession = require './session'
    JSession.one { clientId: client.sessionToken }, (err, session) ->
      return callback err  if err
      return callback new KodingError 'Session not found'  unless session

      query = {}
      query["foreignAuth.#{provider}"] = credentials
      session.update { $set: query }, callback
