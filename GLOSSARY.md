# portal-airplay

An AirPlay receiver for Meta Portal devices, shipped as its own GPL-3.0 app and integrated with the Immortal launcher at arm's length.

## Language

**Receiver**:
The portal-airplay app: the program on a Portal that accepts AirPlay streams. It works on its own, with or without Immortal installed.
_Avoid_: server, AirPlay server, portal-receiver (the retired predecessor)

**Sender**:
The Apple device (iPhone, iPad, Mac) that streams to the Receiver.
_Avoid_: client, source, phone

**Immortal**:
The MIT-licensed launcher on the Portal. It enhances the Receiver when both are installed but never contains it.
_Avoid_: host, launcher (when the integration is meant)

**Contract**:
The published agreement on the messages that pass between Immortal and the Receiver. It is the only coupling between them.
_Avoid_: API, bridge, binding

**Session**:
One continuous period during which a Sender is streaming to the Receiver, from connect to disconnect, across any change of media type within it.
_Avoid_: connection, stream

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
