### 콜록 iOS

https://testflight.apple.com/join/6DEKfQMw

> 멋쟁이사자처럼대학 14기 중앙해커톤 AAC 트랙 128팀 중 **2위** <br />
> 멋쟁이사자처럼대학 14기 중앙해커톤 317팀 중 **장려상**

![thumbnail](https://github.com/user-attachments/assets/0adbf701-3903-4b8a-9939-e91c1984c5e3)
![likelion](https://github.com/user-attachments/assets/d7b19b68-10b4-445d-9b29-db35b93575ae)

```mermaid
flowchart LR
    subgraph IOS["Collog-iOS"]
        UI["SwiftUI<br/>Home, Reports<br/>Timeline, Settings"]
        AUTH["Apple sign-in<br/>AuthenticationServices<br/>Keychain"]
        CALL["CallCenter<br/>CallKit, PushKit<br/>LiveKit SDK"]

        UI --> AUTH
        UI --> CALL
    end

    API["Collog-Server<br/>Auth, family, reports"]
    MEDIA["LiveKit<br/>Voice calls"]
    TTS["ElevenLabs<br/>Question audio"]
    STORAGE[("MinIO<br/>Audio storage")]

    UI <-->|URLSession, REST API| API
    AUTH <-->|Sign-in, token refresh| API
    CALL <-->|Call API, APNs push| API
    CALL <-->|WebRTC| MEDIA
    CALL <-->|Speech streaming| TTS
    CALL -->|16 kHz PCM upload| STORAGE

    classDef screen fill:#14532d,stroke:#14532d,color:#fff
    classDef client fill:#dcfce7,stroke:#22c55e,color:#14532d
    classDef service fill:#eff6ff,stroke:#93c5fd,color:#1e3a8a
    classDef data fill:#f8fafc,stroke:#94a3b8,color:#334155
    class UI screen
    class AUTH,CALL client
    class API,MEDIA,TTS service
    class STORAGE data
    style IOS fill:transparent,stroke:#cbd5e1,stroke-dasharray:5 5
```

<br />
<sub>
© 2026 Team Raichu of LIKELION SeoulTech. All rights reserved.
</sub>
