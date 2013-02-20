class HomeAppController extends AppController

  KD.registerAppClass @, name : "Home"

  constructor:(options = {}, data)->
    # options.view    = new HomeMainView
    options.view    = new KDView
      cssClass      : "content-page home"
    options.appInfo =
      name          : "Home"
      type          : 'background'

    super options,data

  loadView:(mainView)->
    @mainView = mainView
    mainView.putSlideShow()
    widgetHolder = mainView.putWidgets()
    mainView.putTechnologies()
    mainView.putScreenshotDemo()
    mainView.putFooter()
    mainView._windowDidResize()
    @createListControllers()

    widgetHolder.setTemplate widgetHolder.pistachio()
    widgetHolder.template.update()
    widgetHolder.showLoaders()

    @bringFeeds()

  bringFeeds:->
    KD.getSingleton("appManager").tell "Topics", "fetchSomeTopics", null, (err,topics)=>
      unless err
        @mainView.widgetHolder.topicsLoader.hide()
        @topicsController.instantiateListItems topics

    # KD.getSingleton("appManager").tell "Activity", "fetchFeedForHomePage", (activity)=>
    #   if activity
    #     @mainView.widgetHolder.activityLoader.hide()
    #     @activityController.instantiateListItems activity

    KD.getSingleton("appManager").tell "Members", "fetchFeedForHomePage", (err,topics)=>
      unless err
        @mainView.widgetHolder.membersLoader.hide()
        @membersController.instantiateListItems topics

  createListControllers:->
    @createTopicsList()
    @createActivity()
    @createMembersList()

  createTopicsList:->
    @topicsController = new KDListViewController
      view            : new KDListView
        itemClass  : HomeTopicItemView

    @mainView.widgetHolder.topics = @topicsController.getView()

  createActivity:->
    @activityController = new KDListViewController
      view            : new KDListView
        lastToFirst   : no
        itemClass  : HomeActivityItem

    @mainView.widgetHolder.activity = @activityController.getView()

  createMembersList:->
    @membersController = new KDListViewController
      view            : new KDListView
        itemClass  : HomeMemberItemView


    @mainView.widgetHolder.members = @membersController.getView()
