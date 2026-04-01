alias Hub.Documents.{RawDocument, ProcessedDocument, Signal}
alias Hub.Repo

meetings = [
  %{
    source_id: "granola-d1ada8d8",
    topic: "Standup - Mobile/Design",
    start_time: "2026-03-30T10:00:00Z",
    participants: ["Igor Kuznetsov", "Weston Farnsworth", "Matt Jensen", "Jarrette Schule", "Justin Girard"],
    content: """
    Igor Kuznetsov: Working on Crane. Lisa left some feedback on Friday. Preparing a new build to be released, including that new reminder to update the app.
    Weston Farnsworth: Cool.
    Igor Kuznetsov: FNB is not there, so waiting for some API changes with Eric on that. But maybe later this week release it.
    Weston Farnsworth: So you saw some items that Eric needs to finish?
    Igor Kuznetsov: Yes. He promised to finish it today. We need two API endpoints. We have one - new menu items. Another one for locations. Work in progress.
    Weston Farnsworth: A few questions for you on some Jackrabbit stuff. As far as the NFC tap - are we just at a standstill waiting for approval from Apple that Jarrett submitted for? Is there something for Google as well that we need to submit approval for?
    Igor Kuznetsov: I think for Google, it is much simpler. We don't need to do anything special. We can implement it.
    Weston Farnsworth: Of course it is. It's a better run company.
    Igor Kuznetsov: But I've never done that before, so I'm not sure. But for Apple, yeah, I don't know if we received any approval or not.
    Weston Farnsworth: Last email I have from them is ten days ago, March 20. Basically just an auto generated response to my application. Are you gonna start working on the tap for Google then for now?
    Igor Kuznetsov: Very different. But if I could start working on that? Ready to take it, and I can start looking into it.
    Weston Farnsworth: Yeah. And I mean, Jarrett, I'd spend our developer support ticket to Apple right now to ask them what's going on. We've got a few escalation tickets a year. This shouldn't be taking that long to get PassKit approved.
    Matt Jensen: I've done it on other apps, and it doesn't take that long - like twenty four hours for them to approve it last time.
    Weston Farnsworth: As long as Eric finishes the endpoints today, do you think we'll have a TestFlight build the next few days for FNB ordering?
    Igor Kuznetsov: Yeah. Absolutely.
    Weston Farnsworth: Sweet. Matt - ticket number 39 expired tee time fees showing up. That one's still happening.
    Matt Jensen: I think it's just transportation fees. Transpo fees are definitely out of SPs because we had way too many bugs with SPs for them.
    Weston Farnsworth: And purchasing is looking all good for gift cards? Now we just need spending gift cards in pro shop for the egift. Our normal gift cards are unchanged. And we just need to spend in pro shop, right? Because they're doing all of their restaurant through Toast.
    Matt Jensen: Yep. That's the plan right now.
    Weston Farnsworth: What's our timeline for the OHIP integration? They sent over the property code. They're OCVIM, not SSD.
    Matt Jensen: Give me a day to look into it. The documentation on Oracle side is shit. Cody started work on this over a year ago. I'm gonna take it over on the Oracle side. I should be able to finish the egift spending today.
    Justin Girard: I went and saw Matthew yesterday at the course. The system's in progress. One of the employees was able to check me in like two seconds. He did everything fine, didn't need any help.
    Weston Farnsworth: I love that you can go there and see it in action and get some feedback.
    """,
    summary: "Sprint updates across Crane, Jackrabbit, and Birdie. Igor preparing new Crane build with Lisa's feedback, waiting on Eric's FNB API endpoints (menu items + locations). NFC tap for Jackrabbit blocked on Apple PassKit approval (10 days waiting) - team will escalate. Google NFC implementation is simpler, Igor to start on it. Matt finishing egift card spending in pro shop today, investigating Oracle OHIP integration for Grand View Lodge. Justin visited a course and saw the system working well in practice.",
    signals: [
      %{type: "commitment", content: "Eric promised to finish FNB API endpoints today - menu items and locations", speaker: "Igor Kuznetsov", confidence: 0.95},
      %{type: "bug_report", content: "Ticket #39 - expired tee time fees still showing up, likely transportation fees issue", speaker: "Matt Jensen", confidence: 0.8},
      %{type: "feature_request", content: "NFC tap payment for Jackrabbit - Apple PassKit approval pending 10 days, Google implementation ready to start", speaker: "Weston Farnsworth", confidence: 0.9},
      %{type: "commitment", content: "TestFlight build for FNB ordering expected in the next few days", speaker: "Igor Kuznetsov", confidence: 0.85},
      %{type: "commitment", content: "Matt will finish egift card spending today and then investigate Oracle OHIP integration", speaker: "Matt Jensen", confidence: 0.9},
      %{type: "positive_feedback", content: "Course employee was able to check in a customer in two seconds with the new system, no help needed", speaker: "Justin Girard", confidence: 0.85}
    ],
    action_items: [
      %{"text" => "Escalate Apple PassKit approval via developer support ticket", "assignee" => "Jarrette Schule"},
      %{"text" => "Start implementing Google NFC tap for Jackrabbit", "assignee" => "Igor Kuznetsov"},
      %{"text" => "Finish FNB API endpoints (menu items + locations)", "assignee" => "Eric"},
      %{"text" => "Fix ticket #39 - expired tee time transportation fees", "assignee" => "Matt Jensen"},
      %{"text" => "Finish egift card spending in pro shop", "assignee" => "Matt Jensen"},
      %{"text" => "Investigate Oracle OHIP integration for Grand View Lodge", "assignee" => "Matt Jensen"}
    ]
  },
  %{
    source_id: "granola-904d4fc5",
    topic: "Standup - Mobile/Design",
    start_time: "2026-03-25T10:00:00Z",
    participants: ["Igor Kuznetsov", "Weston Farnsworth", "Matt Jensen", "Jarrette Schule", "Justin Girard"],
    content: """
    Weston Farnsworth: Igor, you gonna put an AI agent inside your Buck app?
    Igor Kuznetsov: I think the best what we can do is set money for it and sell tokens.
    Weston Farnsworth: Yeah. They can do stuff like, hey, look through my numbers.
    Igor Kuznetsov: Yeah. Make a graph, review sales of the last two months, do some mapping.
    Weston Farnsworth: That knows all the API and can do whatever you want. It's so cool.
    Justin Girard: Jarrett, just sent you a prototype. This is basically the invoice member invoice tool. I wanted to figure out how to finalize some elements. The UI on the left is highly customizable so you can customize that actual PDF then download it. And you can prompt it to say like, this member bought two drinks, what does that look like in the invoice.
    Weston Farnsworth: Very cool.
    Justin Girard: I'm now building the design system for the card component stuff that we were doing with Weston.
    Matt Jensen: I will have in about thirty minutes a build for Sawyer which will be the 5.3 Birdie. It contains the Sagamore and Kettle Hill stuff plus a few other things for 16.11 and a few of the randoms from the last two weeks.
    Weston Farnsworth: I think this might be a good opportunity to get on to the ID tech devices. Sneak in time on that whenever you can.
    Matt Jensen: I'm anxious to get to the port because getting everything out of the old stuff is going to be life changing. It's mostly the opportunity to use the same logic for the duplicated six different ways of doing things. There's a lot of opportunities to rip out over half of the codebase and not replace it with anything.
    Weston Farnsworth: Since Eric has a home for you now in Gopher, I feel like you're gonna have your own endpoints to mess with. The path of travel is your endpoint and then the Coyote data layer will control all the business logic. We wanna make Coyote very loosey goosey - Coyote will take any kind of input, but the controller will control the validation required for a particular app. Because we can't break Birdie T-sheet when we wanna add a constraint on Buck or Fox.
    Matt Jensen: The only way that I'm going to switch over to using something is if I read it line by line, old and new, and make sure endpoint by endpoint. Maybe just one endpoint at a time. Slow careful steps.
    Weston Farnsworth: I think a big part of the issue was I didn't realize that back nine reservations were posted through Gopher in 5.1. So QA didn't know to test Birdie after deployment. No one realized they were connected. We waited so long to deploy - three and a half weeks - and a lot of stuff changed.
    Matt Jensen: I should be able to finish the egift spending today.
    Weston Farnsworth: Wednesday we're going through the Birdie T-sheet on back nine - designing and reviewing so Austin knows exactly how things are supposed to work. I really wanna be innovative with Birdie - think through long presses, how to physically move tee times, is a double tap something we should consider.
    """,
    summary: "Discussion about AI agent possibilities in Buck app, Justin's invoice tool prototype with Claude artifacts, and Birdie 5.3 release for Sawyer Creek. Matt working on Sagamore and Kettle Hill features. Architecture discussion about Gopher endpoints, Coyote data layer, and careful migration strategy after recent deployment issues with back nine reservations. Planning Wednesday session for Birdie T-sheet UX innovation.",
    signals: [
      %{type: "feature_request", content: "AI agent inside Buck app that can review sales, make graphs, and interact with the API", speaker: "Igor Kuznetsov", confidence: 0.85},
      %{type: "commitment", content: "Birdie 5.3 build for Sawyer Creek ready in 30 minutes with Sagamore and Kettle Hill features", speaker: "Matt Jensen", confidence: 0.95},
      %{type: "bug_report", content: "Back nine reservations were posted through Gopher in 5.1 but nobody realized - caused deployment issues because QA didn't test Birdie after deploy", speaker: "Weston Farnsworth", confidence: 0.9},
      %{type: "positive_feedback", content: "Porting to new architecture will let us rip out over half the codebase - same features, much less code", speaker: "Matt Jensen", confidence: 0.8},
      %{type: "commitment", content: "Wednesday back nine luau session to review Birdie T-sheet design with Austin", speaker: "Weston Farnsworth", confidence: 0.9}
    ],
    action_items: [
      %{"text" => "Finish egift spending implementation", "assignee" => "Matt Jensen"},
      %{"text" => "Get on ID tech devices when time allows", "assignee" => "Matt Jensen"},
      %{"text" => "Wednesday: Review Birdie T-sheet on back nine with Austin", "assignee" => "Weston Farnsworth"},
      %{"text" => "Build design system for card components", "assignee" => "Justin Girard"}
    ]
  },
  %{
    source_id: "granola-d4d346fc",
    topic: "Standup - Mobile/Design",
    start_time: "2026-03-23T10:00:00Z",
    participants: ["Igor Kuznetsov", "Weston Farnsworth", "Matt Jensen", "Jarrette Schule", "Justin Girard"],
    content: """
    Justin Girard: I'm working on this cloud prototype for the Birdie T-sheet. Here's what I have so far.
    Weston Farnsworth: Nice. So what are you thinking for the interaction model?
    Justin Girard: One of the challenges is long press. On a touchscreen, long press is a common gesture, but it conflicts with multi-select mode - if you long press to start multi-select, you can't also use it to open a context menu.
    Igor Kuznetsov: And drag and drop is going to be a problem too. Moving tee times around on a touchscreen versus with a mouse is completely different.
    Justin Girard: Right. The Windows port is coming soon too, so we need to think about mouse and keyboard input alongside touch.
    Weston Farnsworth: What's your proposal?
    Justin Girard: I was thinking peek mode versus action mode. Single click gives you a quick peek at the tee time details - a lightweight preview. Right click, or a long press in touch, gives you the action menu where you can move it, edit it, cancel it.
    Igor Kuznetsov: That makes sense. It separates the read intent from the write intent.
    Weston Farnsworth: I like that. It also means on a mouse you get a natural right-click menu and on touch you get the long press menu.
    Justin Girard: Exactly. And drag and drop would only be active in a specific move mode so it doesn't conflict with scrolling.
    Weston Farnsworth: We should plan some cool design meetings around this. This is the kind of thing worth spending time on.
    Matt Jensen: Agreed. The T-sheet is the core of everything in Birdie.
    """,
    summary: "Justin presented a cloud prototype for the Birdie T-sheet redesign. Team discussed UX challenges around touchscreen gestures — long press conflicts with multi-select mode, and drag-and-drop for moving tee times needs to work on both touch and mouse. Windows port coming soon adds more input considerations.",
    signals: [
      %{type: "feature_request", content: "Drag-and-drop for moving tee times on the T-sheet — needs to work on both touch and mouse without conflicting with scrolling", speaker: "Justin Girard", confidence: 0.9},
      %{type: "feature_request", content: "Peek mode (single click preview) vs action mode (right click/long press menu) for tee time cards on the T-sheet", speaker: "Justin Girard", confidence: 0.9},
      %{type: "commitment", content: "Justin to refine T-sheet prototype based on team feedback and plan dedicated design review sessions", speaker: "Justin Girard", confidence: 0.85}
    ],
    action_items: [
      %{"text" => "Refine Birdie T-sheet prototype with peek/action mode interaction model", "assignee" => "Justin Girard"},
      %{"text" => "Plan dedicated design review sessions for T-sheet UX", "assignee" => "Weston Farnsworth"},
      %{"text" => "Evaluate drag-and-drop implementation for touch vs mouse contexts", "assignee" => "Igor Kuznetsov"}
    ]
  },
  %{
    source_id: "granola-959d83b8",
    topic: "Standup - Mobile/Design",
    start_time: "2026-03-18T10:00:00Z",
    participants: ["Igor Kuznetsov", "Weston Farnsworth", "Matt Jensen", "Jarrette Schule", "Justin Girard"],
    content: """
    Igor Kuznetsov: So I fixed all the issues that were found. There's one backend issue remaining - I need to check with Matt and Eric and Lisa about that.
    Weston Farnsworth: Okay.
    Igor Kuznetsov: Also I did the NFC research and I sent the Apple PassKit entitlement request. They need a couple of days to review.
    Weston Farnsworth: Good. And on Crane?
    Igor Kuznetsov: Working on Crane with the new trade type of tee times. And also the Condor project - I'm packing it as a product. I'll be able to show it next week.
    Weston Farnsworth: Oh nice! Can't wait to see it.
    Igor Kuznetsov: Yeah, it's coming together. Once the backend issue is resolved with Matt and Eric and Lisa we should be good for release.
    Matt Jensen: I'll sync with Eric on that.
    Weston Farnsworth: So you're saying basically Jackrabbit is waiting on one backend thing and then it's ready to go?
    Igor Kuznetsov: Yeah, basically.
    """,
    summary: "Igor completed bug fixes and submitted Apple NFC PassKit entitlement request. Working on Crane with new tee time trade types and packaging Condor as a product for demo next week. One backend issue remaining with Matt/Eric/Lisa before Jackrabbit release.",
    signals: [
      %{type: "commitment", content: "Apple PassKit entitlement request submitted — Apple needs a couple of days to review", speaker: "Igor Kuznetsov", confidence: 0.95},
      %{type: "commitment", content: "Condor project being packaged as a product, demo planned for next week", speaker: "Igor Kuznetsov", confidence: 0.9},
      %{type: "commitment", content: "Jackrabbit release ready once one remaining backend issue is resolved with Matt, Eric, and Lisa", speaker: "Igor Kuznetsov", confidence: 0.9}
    ],
    action_items: [
      %{"text" => "Resolve remaining backend issue for Jackrabbit release", "assignee" => "Matt Jensen"},
      %{"text" => "Await Apple PassKit entitlement review (a couple of days)", "assignee" => "Igor Kuznetsov"},
      %{"text" => "Prepare Condor product demo for next week", "assignee" => "Igor Kuznetsov"}
    ]
  },
  %{
    source_id: "granola-c3531fa9",
    topic: "Standup - Mobile/Design",
    start_time: "2026-03-11T10:00:00Z",
    participants: ["Igor Kuznetsov", "Weston Farnsworth", "Matt Jensen", "Jarrette Schule", "Justin Girard"],
    content: """
    Matt Jensen: I'm focused on Kettle Hills multi-course support today. Going to do a deploy with some data fixes.
    Weston Farnsworth: Good. Are we ready for that?
    Matt Jensen: Yeah, should be good. I'll push it out today.
    Justin Girard: I'm working on the Birdie POS system and the T-sheet design. Doing a lot of research into reservation workflows and how other systems handle it.
    Weston Farnsworth: You been looking at other solutions out there?
    Justin Girard: Yeah. I'm building out the T-sheet in Figma so we can actually see what we're working with before we build it.
    Igor Kuznetsov: I'm working on Jackrabbit. I shared a build with QA. Very close to delivery - probably Friday or Monday.
    Weston Farnsworth: That's great news.
    Igor Kuznetsov: Also reviewing food ordering for Crane. We need an API spec from Swan for that. Have to connect with Eric.
    Weston Farnsworth: Okay, let's make sure that happens.
    Jarrette Schule: I have to tell you guys - Jonathan built a website using Claude in like twelve hours. And this is Jonathan - he's not technical at all.
    Weston Farnsworth: No way.
    Jarrette Schule: Yeah. And it looks great. I was really impressed. It's a good looking site.
    Igor Kuznetsov: That's incredible.
    Weston Farnsworth: This stuff keeps getting better and better. It's really accelerating what non-technical people can produce.
    Jarrette Schule: I have shingles by the way. Not doing great.
    Weston Farnsworth: Oh no! Take care of yourself.
    """,
    summary: "Matt focused on Kettle Hills multi-course support with a deploy planned. Igor has Jackrabbit nearly ready (Friday/Monday target), shared build with QA, and needs API spec for Crane FNB ordering. Justin researching POS workflows and building T-sheet in Figma. Jonathan impressed everyone by building a website with Claude in 12 hours.",
    signals: [
      %{type: "commitment", content: "Jackrabbit delivery targeted for Friday or Monday — build shared with QA", speaker: "Igor Kuznetsov", confidence: 0.95},
      %{type: "commitment", content: "Matt deploying Kettle Hills multi-course fixes today", speaker: "Matt Jensen", confidence: 0.9},
      %{type: "feature_request", content: "FNB ordering for Crane needs Swan API spec — need to connect with Eric to get it", speaker: "Igor Kuznetsov", confidence: 0.85},
      %{type: "positive_feedback", content: "Jonathan (non-technical) built a full website using Claude in 12 hours — team impressed by AI-assisted development potential", speaker: "Jarrette Schule", confidence: 0.9}
    ],
    action_items: [
      %{"text" => "Get API spec from Eric for Crane FNB ordering (Swan)", "assignee" => "Igor Kuznetsov"},
      %{"text" => "Deploy Kettle Hills multi-course data fixes", "assignee" => "Matt Jensen"},
      %{"text" => "Continue QA process for Jackrabbit, target Friday/Monday delivery", "assignee" => "Igor Kuznetsov"},
      %{"text" => "Continue Birdie T-sheet design in Figma", "assignee" => "Justin Girard"}
    ]
  },
  %{
    source_id: "granola-5a51480b",
    topic: "Standup - Mobile/Design",
    start_time: "2026-03-04T10:00:00Z",
    participants: ["Igor Kuznetsov", "Weston Farnsworth", "Matt Jensen", "Jarrette Schule", "Justin Girard", "Cody Sanders"],
    content: """
    Weston Farnsworth: There's a critical bug at Memorial. Fox is allowing the same tee time to be booked by two different users.
    Matt Jensen: How?
    Weston Farnsworth: When a browser tab gets left open past the five minute hold expiration, the hold has expired on the backend but the browser still thinks it's valid. So two people can complete the booking.
    Igor Kuznetsov: That's a pessimistic locking issue. Swan needs to enforce that the hold is still valid at time of purchase.
    Weston Farnsworth: Exactly. Cody, can you make that priority one today?
    Cody Sanders: Yes, I'll fix the overbooking issue first thing.
    Igor Kuznetsov: On my end - I migrated Jackrabbit to Booking Engine v4. Also added customizable button images and clinic session info to Crane.
    Weston Farnsworth: Nice. And did you see the Expo OTA updates thing?
    Igor Kuznetsov: Yes! This is great - we can push hotfixes to apps without going through app store review. Completely over the air.
    Weston Farnsworth: That's going to save us so much time.
    Matt Jensen: I'm testing Birdie in prod and working through backlog tickets.
    Weston Farnsworth: Cody - on the ID.me verification, where are we on that?
    Cody Sanders: I'm implementing it now. Question is whether we show the ID.me button only for discount bookings, or always show it.
    Weston Farnsworth: What's the thinking?
    Cody Sanders: If we only show it for discounts, the flow is cleaner. But if we always show it, members can verify once and never have to do it again in future discount contexts.
    Weston Farnsworth: Let's always show it for now. It's a trust and verification signal even when not strictly required.
    Igor Kuznetsov: There was also a question about base64 image encoding overhead. We looked at it - the overhead is acceptable.
    Weston Farnsworth: Good.
    """,
    summary: "Critical double-booking bug found at Memorial — needs pessimistic locking in Swan backend. Igor migrated Jackrabbit to Booking Engine v4 and discovered Expo OTA updates for instant hotfixes. Cody implementing ID.me verification in Birdie — team decided to always show the ID button rather than only for discount bookings.",
    signals: [
      %{type: "bug_report", content: "Double booking at Memorial — tee time hold expires server-side but browser remains open and allows second booking; needs pessimistic locking in Swan", speaker: "Weston Farnsworth", confidence: 0.98},
      %{type: "feature_request", content: "Expo OTA updates — hotfix apps without app store review, completely over the air", speaker: "Igor Kuznetsov", confidence: 0.9},
      %{type: "commitment", content: "Cody to fix double-booking overbooking bug as priority one today", speaker: "Cody Sanders", confidence: 0.95},
      %{type: "positive_feedback", content: "Jackrabbit migrated to Booking Engine v4 with customizable button images added to Crane", speaker: "Igor Kuznetsov", confidence: 0.85}
    ],
    action_items: [
      %{"text" => "Fix overbooking double-booking bug — add pessimistic locking in Swan", "assignee" => "Cody Sanders"},
      %{"text" => "Implement ID.me verification (always show button)", "assignee" => "Cody Sanders"},
      %{"text" => "Explore Expo OTA update strategy for hotfixes", "assignee" => "Igor Kuznetsov"}
    ]
  },
  %{
    source_id: "granola-bdc7d651",
    topic: "Standup - Mobile/Design",
    start_time: "2026-03-02T10:00:00Z",
    participants: ["Igor Kuznetsov", "Weston Farnsworth", "Matt Jensen", "Jarrette Schule", "Justin Girard"],
    content: """
    Weston Farnsworth: Jackrabbit for Houston is the priority. They don't have a kiosk yet and we want to get it live this week while the team is onsite.
    Igor Kuznetsov: Yes. I'll make sure it's ready.
    Weston Farnsworth: Igor, tell us about the TenFore Portal.
    Igor Kuznetsov: So I built this portal that has a web preview of all our apps. Every time we push an update, the portal automatically updates. You can see the app review status, see what version each white label is on, preview any app in a browser.
    Weston Farnsworth: That is so useful. No more asking what version is running where.
    Matt Jensen: That's going to save a lot of back and forth.
    Igor Kuznetsov: Also - Google rejected the Kettle Hills Android app.
    Weston Farnsworth: Why?
    Igor Kuznetsov: They need an authorization letter from the course saying we're allowed to publish an app on their behalf. It's a brand authorization thing.
    Weston Farnsworth: Got it. Let's get that letter from Kettle Hills.
    Matt Jensen: I've been testing Houston features on prod. Birdie 5.1 rollout is happening - auto-deploy via EloView. CSMs have been briefed to tell courses to update.
    Weston Farnsworth: Good. Where are we on the auth cutover?
    Matt Jensen: All courses except The Ranch are already on 5.1. I think we're ready to push the auth cutover live.
    Weston Farnsworth: Let's do it.
    """,
    summary: "Jackrabbit kiosk priority for Houston while team is onsite. Igor's TenFore Portal now shows web previews of all apps with automatic updates and app review status. Google rejected Kettle Hills Android app — needs brand authorization letter from course. Birdie 5.1 auth cutover imminent — all courses except The Ranch already updated.",
    signals: [
      %{type: "commitment", content: "Jackrabbit live for Houston this week — team onsite, making it the top priority", speaker: "Weston Farnsworth", confidence: 0.95},
      %{type: "positive_feedback", content: "TenFore Portal web preview feature — preview any white label app in browser, automatic updates, shows app review status", speaker: "Igor Kuznetsov", confidence: 0.9},
      %{type: "bug_report", content: "Google rejected Kettle Hills Android app — needs brand authorization letter from the course to publish on their behalf", speaker: "Igor Kuznetsov", confidence: 0.95},
      %{type: "commitment", content: "Birdie 5.1 auth cutover ready to push live — all courses except The Ranch already on 5.1", speaker: "Matt Jensen", confidence: 0.9}
    ],
    action_items: [
      %{"text" => "Get Jackrabbit live for Houston kiosk this week", "assignee" => "Igor Kuznetsov"},
      %{"text" => "Obtain brand authorization letter from Kettle Hills for Google Play", "assignee" => "Weston Farnsworth"},
      %{"text" => "Push Birdie 5.1 auth cutover live", "assignee" => "Matt Jensen"}
    ]
  },
  %{
    source_id: "granola-655ab1e6",
    topic: "Standup: Mobile and Design",
    start_time: "2026-04-01T10:00:00Z",
    participants: ["Igor Kuznetsov", "Jarrette Schule", "Matt Jensen", "Justin Girard"],
    content: """
    Jarrette Schule: I want to show you guys my Claude Cowork automation. So I've been building this thing where Zoom transcripts get processed automatically. It updates my spreadsheet of who's working on what, adds notes to GitHub issues, and moves tickets.
    Igor Kuznetsov: That's really cool. So it reads the transcript and then takes actions?
    Jarrette Schule: Yeah. I set it up with Claude and it just runs. The spreadsheet stays current, the GitHub issues get updated with context from the meeting.
    Justin Girard: I had a meeting with Kettle Hills. There's a lot of missing context for the T-sheet work - I realized we need to understand their full workflow better. Also the waitstaff there gave feedback about managing tables and clocking out. They're doing it from Elo terminals and they hate it - they want to use Clover for that instead.
    Igor Kuznetsov: Interesting. So they want to clock out from Clover instead of the Elo?
    Justin Girard: Yeah. Clover is what they already know. The Elo terminals are for the golf side but the waitstaff ends up having to use both.
    Matt Jensen: I finished the egift work for Grand View. Now switching to Kettle Hills rewards points for transportation.
    Igor Kuznetsov: Good. I released Crane and the white label apps. Now working on FNB for MCG. Also debugging some Jackrabbit subcourse issues. Oh, and Jackrabbit no longer supports check-in for non-authorized users - that was a security concern.
    Jarrette Schule: What was the issue?
    Igor Kuznetsov: Users could look up anyone's personal info through the check-in flow if they weren't an authorized member. So we restricted it.
    Matt Jensen: Makes sense.
    Igor Kuznetsov: Lisa is QAing Jackrabbit today so we should have sign-off soon.
    Jarrette Schule: Speaking of the transcript automation - Igor, you were talking about the Hub idea, right? The platform that centralizes all the meeting transcripts and gives you intelligence across all of them?
    Igor Kuznetsov: Yeah. Imagine if all these standups were automatically processed, you could search across them, see what commitments were made, track what's happening with each client. That's the thing we're building.
    Jarrette Schule: That's exactly what my Cowork thing is trying to do but more systematically.
    """,
    summary: "Jarrette demonstrated his Claude Cowork automation that processes Zoom transcripts into spreadsheet updates and GitHub issue notes. Justin got Kettle Hills feedback — waitstaff struggling with Clover terminal limitations. Matt switching from Grand View egift to Kettle Hills rewards. Igor released Crane, debugging Jackrabbit subcourses and security changes. The Hub transcripts platform concept was discussed — the project that became this system.",
    signals: [
      %{type: "feature_request", content: "Hub transcripts platform — centralized meeting intelligence system to search across standups, track commitments, and surface client insights", speaker: "Igor Kuznetsov", confidence: 0.95},
      %{type: "positive_feedback", content: "Jarrette's Claude Cowork automation processing Zoom transcripts into GitHub issue updates and spreadsheet tracking — working in production", speaker: "Jarrette Schule", confidence: 0.9},
      %{type: "commitment", content: "Lisa QAing Jackrabbit today for client release sign-off", speaker: "Igor Kuznetsov", confidence: 0.9},
      %{type: "bug_report", content: "Jackrabbit check-in for non-authorized users removed — users could look up anyone's personal info through the check-in flow", speaker: "Igor Kuznetsov", confidence: 0.95}
    ],
    action_items: [
      %{"text" => "Await Lisa's QA sign-off on Jackrabbit", "assignee" => "Igor Kuznetsov"},
      %{"text" => "Continue FNB implementation for MCG in Crane", "assignee" => "Igor Kuznetsov"},
      %{"text" => "Debug Jackrabbit subcourse issues", "assignee" => "Igor Kuznetsov"},
      %{"text" => "Implement Kettle Hills rewards points for transportation", "assignee" => "Matt Jensen"},
      %{"text" => "Get more context from Kettle Hills on full T-sheet workflow", "assignee" => "Justin Girard"}
    ]
  }
]

for meeting <- meetings do
  unless Repo.get_by(RawDocument, source: "granola", source_id: meeting.source_id) do
    {:ok, raw_doc} =
      %RawDocument{}
      |> RawDocument.changeset(%{
        source: "granola",
        source_id: meeting.source_id,
        content: meeting.content,
        segments: [],
        participants: meeting.participants,
        metadata: %{
          "topic" => meeting.topic,
          "start_time" => meeting.start_time
        },
        ingested_at: DateTime.utc_now()
      })
      |> Repo.insert()

    {:ok, processed} =
      %ProcessedDocument{}
      |> ProcessedDocument.changeset(%{
        raw_document_id: raw_doc.id,
        summary: meeting.summary,
        action_items: meeting.action_items,
        model: "granola-seed",
        prompt_version: "seed",
        processed_at: DateTime.from_iso8601(meeting.start_time) |> elem(1)
      })
      |> Repo.insert()

    for signal <- meeting.signals do
      %Signal{}
      |> Signal.changeset(%{
        processed_document_id: processed.id,
        type: signal.type,
        content: signal.content,
        speaker: signal.speaker,
        confidence: signal.confidence
      })
      |> Repo.insert!()
    end

    IO.puts("Seeded: #{meeting.topic} (#{meeting.start_time})")
  end
end

IO.puts("Done!")
