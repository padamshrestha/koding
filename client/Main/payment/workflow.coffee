class PaymentWorkflow extends KDController

  @interval:
    MONTH  : 'month'
    YEAR   : 'year'

  @subscription  :
    FREE         : 'free'
    HOBBYIST     : 'hobbyist'
    DEVELOPER    : 'developer'
    PROFESSIONAL : 'professional'

  constructor: (options = {}, data) ->

    super options, data

    @start()
    @initPaymentProvider()


  initPaymentProvider: ->

    return  if window.Stripe?

    options = tagName: 'script', attributes: { src: 'https://js.stripe.com/v2/' }
    document.head.appendChild (@providerScript = new KDCustomHTMLView options).getElement()

    repeater = KD.utils.repeat 500, =>

      return  unless Stripe?

      @modal.emit 'PaymentProviderLoaded', { provider: Stripe }
      window.clearInterval repeater


  start: ->

    { name, monthPrice, yearPrice } = @getOptions()

    @modal = new PaymentModal
      state          :
        subscription : name
        monthPrice   : monthPrice
        yearPrice    : yearPrice


