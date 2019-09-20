import strutils, strformat, sequtils, unicode, tables
import karax/[karaxdsl, vdom, vstyles]

import renderutils, timeline
import ".."/[types, formatters, query]

let toggles = {
  "nativeretweets": "Retweets",
  "media": "Media",
  "videos": "Videos",
  "news": "News",
  "verified": "Verified",
  "native_video": "Native videos",
  "replies": "Replies",
  "links": "Links",
  "images": "Images",
  "safe": "Safe",
  "quote": "Quotes",
  "pro_video": "Pro videos"
}.toOrderedTable

proc renderSearch*(): VNode =
  buildHtml(tdiv(class="panel-container")):
    tdiv(class="search-bar"):
      form(`method`="get", action="/search"):
        hiddenField("kind", "users")
        input(`type`="text", name="text", autofocus="", placeholder="Enter username...")
        button(`type`="submit"): icon "search"

proc getTabClass(query: Query; tab: QueryKind): string =
  result = "tab-item"
  if query.kind == tab:
    result &= " active"

proc renderProfileTabs*(query: Query; username: string): VNode =
  let link = "/" & username
  buildHtml(ul(class="tab")):
    li(class=query.getTabClass(posts)):
      a(href=link): text "Tweets"
    li(class=(query.getTabClass(replies) & " wide")):
      a(href=(link & "/replies")): text "Tweets & Replies"
    li(class=query.getTabClass(media)):
      a(href=(link & "/media")): text "Media"
    li(class=query.getTabClass(custom)):
      a(href=(link & "/search")): text "Search"

proc renderSearchTabs*(query: Query): VNode =
  var q = query
  buildHtml(ul(class="tab")):
    li(class=query.getTabClass(custom)):
      q.kind = custom
      a(href=("?" & genQueryUrl(q))): text "Tweets"
    li(class=query.getTabClass(users)):
      q.kind = users
      a(href=("?" & genQueryUrl(q))): text "Users"

proc isPanelOpen(q: Query): bool =
  q.fromUser.len == 0 and (q.filters.len > 0 or q.excludes.len > 0 or
  @[q.near, q.until, q.since].anyIt(it.len > 0))

proc renderSearchPanel*(query: Query): VNode =
  let user = query.fromUser.join(",")
  let action = if user.len > 0: &"/{user}/search" else: "/search"
  buildHtml(form(`method`="get", action=action, class="search-field")):
    hiddenField("kind", "custom")
    genInput("text", "", query.text, "Enter search...",
             class="pref-inline", autofocus=true)
    button(`type`="submit"): icon "search"
    if isPanelOpen(query):
      input(id="search-panel-toggle", `type`="checkbox", checked="")
    else:
      input(id="search-panel-toggle", `type`="checkbox")
    label(`for`="search-panel-toggle"):
      icon "down"
    tdiv(class="search-panel"):
      for f in @["filter", "exclude"]:
        span(class="search-title"): text capitalize(f)
        tdiv(class="search-toggles"):
          for k, v in toggles:
            let state =
              if f == "filter": k in query.filters
              else: k in query.excludes
            genCheckbox(&"{f[0]}-{k}", v, state)

      tdiv(class="search-row"):
        tdiv:
          span(class="search-title"): text "Time range"
          tdiv(class="date-range"):
            genDate("since", query.since)
            span(class="search-title"): text "-"
            genDate("until", query.until)
        tdiv:
          span(class="search-title"): text "Near"
          genInput("near", "", query.near, placeholder="Location...")

proc renderTweetSearch*(tweets: Result[Tweet]; prefs: Prefs; path: string): VNode =
  let query = tweets.query
  buildHtml(tdiv(class="timeline-container")):
    if query.fromUser.len > 1:
      tdiv(class="timeline-header"):
        text query.fromUser.join(" | ")
    if query.fromUser.len == 0 or query.kind == custom:
      tdiv(class="timeline-header"):
        renderSearchPanel(query)

    if query.fromUser.len > 0:
      renderProfileTabs(query, query.fromUser.join(","))
    else:
      renderSearchTabs(query)

    renderTimelineTweets(tweets, prefs, path)

proc renderUserSearch*(users: Result[Profile]; prefs: Prefs): VNode =
  buildHtml(tdiv(class="timeline-container")):
    tdiv(class="timeline-header"):
      form(`method`="get", action="/search", class="search-field"):
        hiddenField("kind", "users")
        genInput("text", "", users.query.text, "Enter username...", class="pref-inline")
        button(`type`="submit"): icon "search"

    renderSearchTabs(users.query)
    renderTimelineUsers(users, prefs)
