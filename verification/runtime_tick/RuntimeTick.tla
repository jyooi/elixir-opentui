---- MODULE RuntimeTick ----
EXTENDS Naturals, Sequences, FiniteSets

CONSTANTS MaxQueue, MaxSuspend, MaxRefs, MaxOrphans

VARIABLES srv, orphans, mailbox

vars == <<srv, orphans, mailbox>>

ShouldTick(st) == st.live \/ st.refs > 0 \/ st.explicit

HasTick(box) == \E i \in 1..Len(box) : box[i] = "tick"

WithStaleTick(box) ==
  IF ~HasTick(box) THEN box
  ELSE LET i == CHOOSE i \in 1..Len(box) :
                   box[i] = "tick" /\ \A j \in 1..(i - 1) : box[j] # "tick"
       IN [box EXCEPT ![i] = "stale"]

CancelTimer(w) ==
  IF w.s.held = "fired" THEN [w EXCEPT !.m = WithStaleTick(w.m)] ELSE w

StartLoop(w) ==
  IF w.s.control = "running" \/ w.s.count > 0
  THEN w
  ELSE [CancelTimer(w) EXCEPT !.s.control = "running", !.s.held = "armed"]

StopLoop(w) ==
  [CancelTimer(w) EXCEPT !.s.control = IF w.s.count > 0 THEN "suspended" ELSE "idle",
                         !.s.held = "none"]

StopUnlessWanted(w) == IF ShouldTick(w.s) THEN w ELSE StopLoop(w)

Reconcile(w) ==
  IF w.s.control = "suspended" THEN w
  ELSE IF ShouldTick(w.s) /\ w.s.control = "idle" THEN StartLoop(w)
  ELSE IF ~ShouldTick(w.s) /\ w.s.control = "running" THEN StopLoop(w)
  ELSE w

Pending(kind) == Cardinality({i \in 1..Len(mailbox) : mailbox[i] = kind})

TickSources == (IF srv.held = "armed" THEN 1 ELSE 0) + orphans + Pending("tick")

Init ==
  /\ srv = [control |-> "idle", count |-> 0, explicit |-> FALSE,
            refs |-> 0, live |-> FALSE, held |-> "none"]
  /\ orphans = 0
  /\ mailbox = <<>>

Send(request) ==
  /\ Len(mailbox) < MaxQueue
  /\ mailbox' = Append(mailbox, request)
  /\ UNCHANGED <<srv, orphans>>

CallStart == Send("start")
CallStop == Send("stop")
CallRequestLive == srv.refs + Pending("request_live") < MaxRefs /\ Send("request_live")
CallDropLive == Send("drop_live")
CallSuspend == srv.count + Pending("suspend") < MaxSuspend /\ Send("suspend")
CallResume == Send("resume")
SendEvent == Send("event")

TimerFires ==
  /\ \/ /\ srv.held = "armed"
        /\ srv' = [srv EXCEPT !.held = "fired"]
        /\ UNCHANGED orphans
     \/ /\ orphans > 0
        /\ orphans' = orphans - 1
        /\ UNCHANGED srv
  /\ mailbox' = Append(mailbox, "tick")

Taken(st) == [s |-> st, m |-> Tail(mailbox)]

Handle(request, next) ==
  /\ mailbox # <<>>
  /\ Head(mailbox) = request
  /\ srv' = next.s
  /\ mailbox' = next.m
  /\ UNCHANGED orphans

HandleStart == Handle("start", StartLoop(Taken([srv EXCEPT !.explicit = TRUE])))

HandleStop == Handle("stop", StopUnlessWanted(Taken([srv EXCEPT !.explicit = FALSE])))

HandleRequestLive == Handle("request_live", StartLoop(Taken([srv EXCEPT !.refs = @ + 1])))

HandleDropLive ==
  Handle("drop_live",
    IF srv.refs = 0 THEN Taken(srv)
    ELSE StopUnlessWanted(Taken([srv EXCEPT !.refs = @ - 1])))

HandleSuspend ==
  Handle("suspend", Taken([srv EXCEPT !.count = @ + 1, !.control = "suspended"]))

HandleResume ==
  Handle("resume",
    LET st == [srv EXCEPT !.count = IF @ > 0 THEN @ - 1 ELSE 0]
    IN IF st.count > 0 THEN Taken(st)
       ELSE IF ShouldTick(st) THEN StartLoop(Taken(st))
       ELSE Taken([st EXCEPT !.control = "idle"]))

HandleEvent ==
  \E live \in BOOLEAN : Handle("event", Reconcile(Taken([srv EXCEPT !.live = live])))

HandleTick ==
  /\ mailbox # <<>>
  /\ Head(mailbox) = "tick"
  /\ IF srv.control # "running"
     THEN /\ mailbox' = Tail(mailbox)
          /\ UNCHANGED <<srv, orphans>>
     ELSE \E live \in BOOLEAN :
            LET st == [srv EXCEPT !.live = live]
            IN IF ShouldTick(st)
               THEN /\ srv' = [st EXCEPT !.held = "armed"]
                    /\ mailbox' = Tail(mailbox)
                    /\ orphans' = orphans + (IF srv.held = "armed" THEN 1 ELSE 0)
               ELSE /\ srv' = StopLoop(Taken(st)).s
                    /\ mailbox' = StopLoop(Taken(st)).m
                    /\ UNCHANGED orphans

HandleStaleTick ==
  /\ mailbox # <<>>
  /\ Head(mailbox) = "stale"
  /\ mailbox' = Tail(mailbox)
  /\ UNCHANGED <<srv, orphans>>

Next ==
  \/ CallStart \/ CallStop \/ CallRequestLive \/ CallDropLive
  \/ CallSuspend \/ CallResume \/ SendEvent
  \/ TimerFires
  \/ HandleStart \/ HandleStop \/ HandleRequestLive \/ HandleDropLive
  \/ HandleSuspend \/ HandleResume \/ HandleEvent \/ HandleTick \/ HandleStaleTick

Spec == Init /\ [][Next]_vars

OrphanBound == orphans <= MaxOrphans

SuspendedExactlyWhileSuspendCalls == (srv.count > 0) <=> (srv.control = "suspended")

OneTickChain == TickSources <= 1

TicksWhenDue ==
  (srv.count = 0 /\ ShouldTick(srv)) => (srv.control = "running" /\ TickSources >= 1)

====
