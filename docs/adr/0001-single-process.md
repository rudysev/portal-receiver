# One process, despite native code that parses network input

The Receiver runs UxPlay's C core, which parses traffic from any Sender on the network, in the same process as the Session logic, the Surface and the Immortal-facing Contract. A native crash therefore takes the whole Receiver down. We chose this over running the engine in its own `:engine` process because isolation would add an internal message channel and a second lifecycle (startup ordering, rebinding, a second death path), all behind a one-Sender-at-a-time receiver. The recovery it would buy is already covered elsewhere: the Contract requires Immortal to treat ownership as released when the Receiver dies (#5), the foreground service restarts the Receiver, and a crash-loop guard (3 crashes in 10 minutes) stops it and reports Status "unavailable" instead of restarting endlessly.

## Consequences

- A native crash ends any Session in progress. The Sender has to reconnect.
- Revisit this decision if crashes in the field are frequent enough that a Session-ending crash is a real user problem, or if a patched UxPlay flaw turns out to be exploitable rather than just a crash. Moving the engine to its own process would change `:engine`'s adapter and none of `:session`'s interface, because the engine already only emits events and accepts a few commands.
