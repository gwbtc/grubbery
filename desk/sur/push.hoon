::  sur/push: web push notification types
::
::  p256dh and auth are MSB-first atoms (crypto convention)
::
|%
+$  subscription  [endpoint=@t p256dh=@ auth=@]
+$  push-config  [private-key=@ public-key=@ sub=@t]
+$  push-message
  $:  title=@t
      body=@t
      icon=(unit @t)
      url=(unit @t)
      tag=(unit @t)
  ==
+$  push-send
  $:  targets=(set @p)    ::  specific ships (empty = all subscribed)
      tags=(set term)     ::  filter by tag prefs (empty = no filtering)
      exclude=(set @p)    ::  remove these ships from recipients
      msg=push-message
  ==
+$  delivery-status  ?(%pending %sent %failed %expired %gone)
+$  send-key  [ship=@p sub-id=@ta notif-id=@ud]
+$  delivery
  $:  title=@t
      sent-at=@da
      =delivery-status
  ==
--
