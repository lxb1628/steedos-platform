getTempNavsFromCache = ()->
    cachedTempNavsStr = sessionStorage.getItem("temp_navs")
    if cachedTempNavsStr
        return cachedTempNavsStr.split(",").map (item)->
            itemValues = item.split(":")
            return {
                name: itemValues[0],
                url: itemValues[1],
                label: itemValues[2],
                is_temp: true
            }

getTempNavsIdFromCache = (userId, spaceId, appId)->
    return sessionStorage.getItem("temp_navs_id")

saveTempNavsIdToCache = (value)->
    sessionStorage.setItem("temp_navs_id", value)

saveTempNavsToCache = (tempNavs)->
    # key格式：`tempNavs:${userId}:${spaceId}:${appId}`
    # value格式：`${name1},${name2},${name3}:${url}:${label}`
    unless tempNavs
        tempNavs = []
    values = tempNavs.map (item)->
        itemValueStr = item.name
        if item.url
            itemValueStr += ":#{item.url}"
        if item.label
            itemValueStr += ":#{item.label}"
    valueStr = values.join(",")
    sessionStorage.setItem("temp_navs", valueStr)

# 不增加lastRemovedTempNavUrls相关逻辑的话，删除导航栏有时会出现死循环删除不掉的情况
lastRemovedTempNavUrls = []

appendLastRemovedTempNavUrl = (name, url)->
    lastRemovedTempNavUrl = if url then url else Creator.getObjectUrl(name)
    lastRemovedTempNavUrls.push lastRemovedTempNavUrl

removeLastRemovedTempNavUrl = (name, url)->
    lastRemovedTempNavUrl = if url then url else Creator.getObjectUrl(name)
    index = lastRemovedTempNavUrls.indexOf(lastRemovedTempNavUrl)
    if index > -1
        lastRemovedTempNavUrls.splice(index, 1)

getValidLastUrl = (name, url)->
    curentUrl = if url then url else Creator.getObjectUrl(name)
    # 从urlQuery中找到最近的一个上次打开的url，但是该url不可以在lastRemovedTempNavUrls中
    i = 2
    maxBackCount = 3
    lastUrlEnabled = false
    while !lastUrlEnabled and i < 2 + maxBackCount
        index = urlQuery.length - i
        if index < 0
            break
        lastUrl = urlQuery[index]
        if __meteor_runtime_config__.ROOT_URL_PATH_PREFIX + lastUrl == curentUrl
            i++
            continue
        lastUrlEnabled = lastUrl and lastRemovedTempNavUrls.indexOf(__meteor_runtime_config__.ROOT_URL_PATH_PREFIX + lastUrl) < 0
        i++
    return if lastUrlEnabled then lastUrl else null

redirectBeforeRemoveTempNav = (name, url, tempNavsAfterRemove, removeAtIndex)->
    currentObjectName = Session.get("object_name")
    currentRecordId = Session.get("record_id")
    if url
        currentUrl = Creator.getObjectUrl(currentObjectName, currentRecordId)
        isCurrentNav = currentUrl == url
    else
        isCurrentNav = currentObjectName == name
    if isCurrentNav
        # 如果当前打开中的Url与需要被关闭的导航栏项一样，则优先返回到上一个url（除非找不到）
        # 其次再取tempNavs中最近的一个导航（先右再左），最后才取Creator.getAppObjectNames()中最后一个导航来跳转
        lastUrl = getValidLastUrl(name, url)
        appendLastRemovedTempNavUrl(name, url)
        if lastUrl
            # urlQuery记录的是不带__meteor_runtime_config__.ROOT_URL_PATH_PREFIX前缀的相对路径，可以直接go
            FlowRouter.go(lastUrl)
        else
            # tempNavs中保存的url是带__meteor_runtime_config__.ROOT_URL_PATH_PREFIX前缀的相对路径，需要用redirect
            toNav = tempNavsAfterRemove[removeAtIndex]
            unless toNav
                toNav = tempNavsAfterRemove[removeAtIndex - 1]
            if toNav
                toNavUrl = if toNav.url then toNav.url else Creator.getObjectUrl(toNav.name)
                FlowRouter.redirect(toNavUrl)
            else
                objectNames = Creator.getAppObjectNames()
                lastObjectName = objectNames[objectNames.length - 1]
                FlowRouter.redirect(Creator.getObjectUrl(lastObjectName))
    else
        appendLastRemovedTempNavUrl(name, url)

Creator.getTempNavs = ()->
    tempNavs = Session.get("temp_navs")
    unless tempNavs
        tempNavs = getTempNavsFromCache()
        if tempNavs
            Session.set("temp_navs", tempNavs)
    return tempNavs

Creator.getTempNavsId = ()->
    tempNavsId = Session.get("temp_navs_id")
    unless tempNavsId
        tempNavsId = getTempNavsIdFromCache()
        if tempNavsId
            Session.set("temp_navs_id", tempNavsId)
    return tempNavsId

Creator.createTempNav = (name, url, label)->
    tempNavs = Creator.getTempNavs()
    unless tempNavs
        tempNavs = []
    existingNav = tempNavs.find (item)->
        if url
            return item.name == name and item.url == url
        else
            return item.name == name
    unless existingNav
        tempNavs.push {name, url, label, is_temp: true}
        Session.set("temp_navs", tempNavs)
        saveTempNavsToCache(tempNavs)
        removeLastRemovedTempNavUrl(name, url)

Creator.removeTempNavItem = (name, url)->
    tempNavs = Session.get("temp_navs")
    unless tempNavs
        return
    skipIndex = null
    result = tempNavs.filter (item, index)->
        if url
            skip = item.name == name and item.url == url
        else
            skip = item.name == name
        if skip
            skipIndex = index
        return !skip
    if !_.isNumber(skipIndex)
        return
    redirectBeforeRemoveTempNav(name, url, result, skipIndex)
    Meteor.defer ()->
        Session.set("temp_navs", result)
        saveTempNavsToCache(result)

Creator.resetTempNavsIfNeeded = ()->
    # 切换应用、工作区时，需要清除当前的tempNavs
    tempNavsId = Creator.getTempNavsId()
    currentTempNavsId = "#{Meteor.userId()}:#{Steedos.spaceId()}:#{Session.get("app_id")}"
    neededToReset = tempNavsId != currentTempNavsId
    if neededToReset
        Session.set("temp_navs", null)
        saveTempNavsToCache(null)
    if neededToReset or !Session.get("temp_navs_id")
        Session.set("temp_navs_id", currentTempNavsId)
        saveTempNavsIdToCache(currentTempNavsId)

Meteor.startup ()->
    # 切换工作区时或APP时重置temp_navs值
    Tracker.autorun ()->
        spaceId = Session.get("spaceId")
        appId = Session.get("app_id")
        if spaceId and appId
            Creator.resetTempNavsIfNeeded()

    Tracker.autorun (c)->
        objectName = Session.get("object_name")
        recordId = Session.get("record_id")
        unless objectName
            return
        record = Creator.getObjectRecord()
        objectNames = Creator.getAppObjectNames()
        # 如果当前所在的object_name不存在顶部导航中，则添加一个临时的导航栏项
        if objectNames?.indexOf(objectName) < 0
            object = Creator.getObject(objectName)
            unless object
                return
            if recordId
                url = Creator.getObjectUrl(objectName, recordId)
                unless record
                    return
                nameField = object.NAME_FIELD_KEY || "name"
                label = record[nameField]
                Creator.createTempNav(objectName, url, label)
            else
                Creator.createTempNav(objectName)

