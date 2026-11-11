# Self-hosting the buzzer server

Macpardy's phone buzzers normally run inside the app (the **built-in server**). The
**self-hosted server** is the same buzzer as a Docker container, so phones on other networks
can join over the internet (#99).

> **Phones on the same network as the Mac? Use the built-in server.** It needs no setup and
> it's the default.

The server, its Docker image and the full setup guide (Docker and compose, DuckDNS and port
forwarding, the reverse proxy and HTTPS, the host token, limits and the grace period) live in
their own repo:

**[Macpardy-Buzzer-Server](https://github.com/liljimmyk99/Macpardy-Buzzer-Server)**, guide: [docs/self-hosting.md](https://github.com/liljimmyk99/Macpardy-Buzzer-Server/blob/master/docs/self-hosting.md)

In the app: **Settings > Buzzers**, choose **External server**, and enter `https://<your domain>`
and the host token (see [features.md](features.md)). The wire format is in
[buzzer-protocol.md](buzzer-protocol.md#self-hosted-server).
