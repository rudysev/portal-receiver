# Portal Receiver

An AirPlay receiver for Meta Portal devices, shipped as its own GPL-3.0 app and integrated with the Immortal launcher at arm's length.

## Language

**Receiver**:
The Portal Receiver app: the program on a Portal that accepts AirPlay streams. It works on its own, with or without Immortal installed.
_Avoid_: server, AirPlay server, prototype (the archived proof of concept, portal-receiver-prototype)

**Sender**:
The Apple device (iPhone, iPad, Mac) that streams to the Receiver.
_Avoid_: client, source, phone

**Immortal**:
The MIT-licensed launcher on the Portal. It enhances the Receiver when both are installed but never contains it.
_Avoid_: host, launcher (when the integration is meant)

**Portal name**:
The Portal's own name, which the user sets in Immortal (Immortal calls it "Device name"). By default the Receiver advertises under it.
_Avoid_: hostname, Bonjour name

**Contract**:
The published agreement on the messages that pass between Immortal and the Receiver. It is the only coupling between them.
_Avoid_: API, bridge, binding

**Session**:
One continuous period during which a Sender is streaming to the Receiver, from connect to disconnect, across any change of media type within it.
_Avoid_: connection, stream

**Media type**:
What a Session is carrying at a given moment: Audio only, Mirroring or AirPlay video. It can change within one Session.
_Avoid_: mode, session type

**Audio only**:
A Session in which the Sender sends sound and no picture. It never takes the screen.
_Avoid_: music mode, RAOP

**Mirroring**:
A Session in which the Sender sends its own screen as live video.
_Avoid_: screen cast

**AirPlay video**:
A Session in which the Sender hands the Receiver a media URL to play itself, rather than sending pixels.
_Avoid_: HLS mode, casting

**Handover**:
The change within one Session from Mirroring to AirPlay video, as YouTube does.
_Avoid_: switch, reset

**Speaker ownership**:
Which program currently has the right to play through the Portal's speakers.
_Avoid_: audio focus (Android's mechanism, which is only one possible means)

**Screen ownership**:
Which program currently has the right to fill the Portal's screen. The Receiver holds it for Mirroring, AirPlay video and a pairing PIN prompt, never for Audio only.
_Avoid_: foreground, on top

**Surface**:
The Receiver's full-screen view, which shows a Session's picture or a pairing PIN.
_Avoid_: player, overlay, window

**Status**:
Whether the Receiver is currently disabled, advertising under its name, or unavailable (with a reason).
_Avoid_: state (reserved for a Session), health
