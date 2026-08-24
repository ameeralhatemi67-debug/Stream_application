# Comparative Feasibility and Architectural Analysis of Cloud-Native Educational Streaming (Path 1)

This report evaluates the technical viability, structural complexity, financial parameters, and regulatory conditions of deploying a fully cloud-native infrastructure—designated as Path 1—for an educational streaming platform starting in the Al Khobar region of Saudi Arabia. Path 1 relies entirely on hyperscale public cloud providers to manage the live ingest, transcoding, edge distribution, real-time interactive message delivery, and automated Video-On-Demand (VOD) archiving of lectures, mosque talks, and community speeches.

## Technical Architecture of the Cloud-Native Media Pipeline

Implementing a cloud-native model requires an end-to-end media pipeline optimized for low-latency delivery within the Middle East. The ingestion process starts at local venues in Al Khobar, where physical audio-video feeds are captured, encoded, and pushed over local fiber networks to the cloud infrastructure.

![[First.png]]
### Ingestion and Transcoding Core

The core live streaming engine is built on Amazon Interactive Video Service (IVS), a managed service designed for highly interactive, low-latency live video experiences. Local encoders at the Al Khobar venues transmit feeds using Real-Time Messaging Protocol (RTMP) or Secure Reliable Transport (SRT) directly to the ingest endpoints of the AWS Saudi Arabia Region (`me-central-2`) based in Riyadh.

The launch of `me-central-2` in January 2026 allows the ingestion process to bypass public internet routes by peering directly with local telecommunications networks. Operating within this region guarantees that the media streams are ingested with minimal network jitter, securing robust packet delivery directly at the regional source.

Upon ingestion, AWS IVS automatically transcodes the input stream into an adaptive bitrate (ABR) ladder—including 1080p, 720p, 480p, and 360p resolutions. This enables the platform to deliver high-definition video to viewers on fast home fiber while maintaining a continuous stream for mobile users on variable cellular connections.

### Edge Distribution and Playback

The transcoded streams are packaged into Low-Latency HTTP Live Streaming (LL-HLS) format. Delivery is accelerated by Amazon CloudFront's global Content Delivery Network (CDN). CloudFront operates a local edge location in Jeddah (launched in January 2025), which features AWS Shield Standard for inline DDoS mitigation and AWS Web Application Firewall (WAF) integration.

By caching stream segments at the edge, CloudFront minimizes the physical distance data must travel to reach viewers in Al Khobar, keeping end-to-end playback latency under three seconds. The player integration is handled on mobile and web frontends via the Amazon IVS Player SDK, which is designed to handle player buffers dynamically on cellular networks.

### Platform-Wide Technical Comparison

To validate the hyperscaler strategy, the table below compares the two primary cloud ecosystems available for deployment within Saudi Arabia: AWS (relying on Amazon IVS and CloudFront) and Alibaba Cloud (operating as SCCC via stc, utilizing ApsaraVideo Live and the Global Real-time Transport Network).

|**Feature Dimension**|**Amazon Web Services (AWS) Path**|**Alibaba Cloud (SCCC) Path**|**Architectural Significance**|
|---|---|---|---|
|**Primary Live Service**|Amazon Interactive Video Service (IVS)|ApsaraVideo Live|Dictates the API structure, ingest method, and player SDK integration.|
|**In-Country Region**|Riyadh (`me-central-2`), Launched Jan 2026|Riyadh (SCCC by stc), Established local hosting|Guarantees complete data sovereignty and complies with local PDPL mandates.|
|**Local Edge Footprint**|Jeddah Edge Node (Jan 2025) + regional peers|Dense stc-backed domestic CDN nodes|Crucial for avoiding packet loss and minimizing latency for local viewers in Al Khobar.|
|**Ingest Protocols**|RTMP, RTMPS, and native SRT|RTMP, SRT, and Real-Time Streaming (RTS)|SRT is preferred for local sites with variable network quality due to its ARQ recovery.|
|**VOD Integration**|Automated write-to-S3 bucket with instant manifest generation|Integrated ApsaraVideo VOD storage and media processing|Automates the transition from live event to archived VOD logs without custom pipelines.|

## Technical and Software Complexity

While Path 1 eliminates the need to manage physical servers, it introduces integration complexities across the media pipeline, player SDKs, custom metadata synchronizations, and data archival.

### Ingest and Transcoding Configuration

Developers must configure AWS IVS Channel Types based on quality and financial trade-offs. Standard channels support inputs up to 1080p at 8.5 Mbps and generate a full ABR ladder. They also support Multitrack Video, which allows compatible encoders to send pre-rendered quality levels directly, reducing ingest costs.

In contrast, basic channels support inputs up to 1080p at 3.5 Mbps or 480p at 1.5 Mbps but do not perform server-side transcoding. They deliver only the original input quality directly to the viewer. This represents a significant risk for mobile viewers in Al Khobar, as any local network congestion will cause severe buffering without a lower-resolution stream to fall back on.

### Player and Frontend Integration

The mobile application (iOS and Android) must embed the native Amazon IVS Player SDK. To ensure a seamless user experience, developers must implement custom connection-monitoring algorithms. On high-speed home fiber networks, the player is configured to operate in "Ultra-Low Latency" mode, maintaining a tight playback buffer of 1.5 to 2.0 seconds.

If the SDK detects fluctuating network conditions, such as high round-trip time (RTT) jitter on local cellular networks, the player must automatically increase its buffer size to 5 or 6 seconds. This prevents playback freezes by prioritizing stream continuity over raw latency.

### Interactive Feature Engineering

The app's unique value proposition is its real-time interactivity, allowing viewers to ask questions, perform gestures, and log custom events. In a cloud-native setup, these are handled using two distinct architectural mechanisms:

![[second.png]]

1. **Real-Time Questions (IVS Chat SDK):** AWS provides a managed Chat feature that operates alongside the video stream. Developers integrate the IVS Chat SDK, which establishes a WebSocket connection to a secure chat room resource. When a viewer asks a question, the message is sent via WebSocket, validated through an AWS Lambda authorizer, and broadcast to all connected clients. Chat rooms can be programmatically cleared, moderated, or paused.
2. **Gestures and Custom Events (IVS Timed Metadata):** "Gestures" (like clapping or raising hands) and "events" are highly time-sensitive. If a user raises a hand, that gesture must render on-screen exactly when the speaker says something relevant, despite any playback latency. Routing gestures through an external database or standard WebSocket server will cause them to appear out of sync with the video. To solve this, developers use the **AWS IVS PutMetadata API** to inject metadata payloads directly into the live video transmuter. These payload packets are embedded as ID3 tags inside the video container segments. When the player parses these segments, the Player SDK fires a local callback event containing the metadata payload, allowing the client app to render the hand-raising gesture on the viewer's screen with frame-accurate synchronization.

### Automated VOD Archiving Engine

Saving all stream logs for future access is a core requirement of this project. Path 1 automates this process through native storage integrations. When creating an AWS IVS channel, developers associate it with an **Amazon S3 Recording Configuration**.

Once streaming begins, IVS automatically writes the raw incoming TS segments and corresponding index files (.m3u8) directly to a designated Amazon S3 bucket in `me-central-2`. Upon stream termination, a master manifest is generated, making the stream instantly available as an archived VOD asset.

To optimize long-term storage costs, developers must implement **S3 Lifecycle Policies**. Raw streaming assets are initially stored in S3 Standard to ensure immediate VOD availability. After 30 days, the files are transitioned to S3 Glacier Flexible Archive, and eventually to S3 Glacier Deep Archive after 90 days. This tiering reduces storage costs by up to 95% while keeping the master media logs secure and compliant with data preservation rules.

## Legacy Log Migration and VOD Integration

A critical functional requirement is the ingestion of the platform's existing, pre-recorded stream logs so that users can access them alongside newly recorded cloud broadcasts. Under Path 1, this requires a dedicated migration and media processing workflow to standardize legacy assets.

![[3ird.png]]

### Batch Ingestion and Transcoding Workflow

The existing stream logs, typically stored in flat format containers such as MP4 or MKV, must be bulk-uploaded to a secure ingestion bucket in the Amazon S3 Riyadh region. Because raw progressive-download MP4 files perform poorly on mobile networks due to the lack of adaptive bitrate adaptation, these files must be converted to standard streaming formats.

Path 1 handles this through **AWS Elemental MediaConvert**, a file-based transcoding service. Upon upload, an S3 event trigger fires an AWS Lambda function that submits a MediaConvert job. This job transcodes the legacy video files into HLS directories, replicating the exact multi-bitrate ABR ladder (1080p, 720p, 480p, 360p) generated by the live AWS IVS streams.

### Unified Playback and Database Indexing

The transcoded HLS directories and manifest files are saved to a production S3 bucket configured for edge delivery via Amazon CloudFront. Simultaneously, the Lambda function writes a database entry to **Amazon DynamoDB** containing the video's metadata, such as the title, date, speaker, topic, and the CloudFront playback URL.

This database acts as the master directory for the client application. When a user opens the app, the interface queries the DynamoDB database via an API gateway, displaying both legacy archived lectures and newly completed live stream recordings in a unified VOD catalog.

## Local ISP Infrastructure and Venue Constraints

The performance of a cloud-native platform relies heavily on the physical internet connections and encoding hardware at each venue in Al Khobar.

### Al Khobar ISP Mapping

Local venues in Al Khobar must have a stable internet connection with sufficient upload speed. While residential fiber connections offer high download speeds, they are often asymmetrical and shared, which can lead to upload speed drops during peak hours.

To prevent stream instability, local venues should use dedicated business-grade fiber lines. The table below outlines the business connectivity options available in Al Khobar:

|**ISP Provider**|**Package Type**|**Symmetrical Speeds (Download/Upload)**|**Monthly Price (SAR, VAT Incl.)**|**Suitability for Path 1 Ingestion**|
|---|---|---|---|---|
|**stc**|Fiber Link 100|100 Mbps / 20 Mbps|344 SAR|**Highly Suitable.** Easily supports a single Standard 1080p stream at 8.5 Mbps with plenty of overhead.|
|**stc**|Fiber Link 500|500 Mbps / 200 Mbps|1,149 SAR|**Optimal for Multi-Streaming.** Symmetrical upload easily supports simultaneous high-bitrate streaming backups or secondary streams.|
|**Salam**|Business Fiber 300|300 Mbps / 100 Mbps|290 SAR|**Highly Cost-Effective.** Excellent value for mid-tier venues needing reliable upload bandwidth.|

### Minimum Bandwidth Requirements for Ingestion

To maintain a buffer-free live stream, the local ingest connection must provide dedicated, unshared upload speed. The network configuration must follow strict safety margins based on the chosen IVS channel type:

$$\text{Required Dedicated Upload Speed} \ge 1.5 \times \text{Stream Ingest Bitrate}$$

1. **Standard Channels (1080p @ 60 FPS):** Streaming at a target video bitrate of 6.5 Mbps plus 192 Kbps for audio requires a continuous upload rate of roughly 6.7 Mbps. Applying a $1.5\times$ safety factor to account for packet retransmissions and local network jitter, the venue requires **at least 10 Mbps of dedicated upload bandwidth**.
2. **Basic Channels (480p @ 30 FPS):** Streaming at a target video bitrate of 1.2 Mbps plus 128 Kbps for audio requires a continuous upload rate of roughly 1.3 Mbps. Applying the $1.5\times$ safety factor, the venue requires **at least 2 Mbps of dedicated upload bandwidth**.

### Local Venue Hardware Configuration

Because Path 1 offloads the transcoding workload to the cloud, the hardware requirements at local venues are relatively light. Venues must purchase PTZ (Pan-Tilt-Zoom) cameras that output high-definition feeds via HDMI or SDI. To compress these feeds into RTMP/SRT streams, venues can use dedicated hardware encoders, which offer greater reliability than general-purpose computers.

Alternatively, if using software-based encoders like OBS Studio or vMix, the on-site PC must have a dedicated GPU (such as an NVIDIA RTX series card) to handle hardware-accelerated H.264/H.265 encoding. This ensures consistent frame delivery without placing heavy demands on the system's CPU.

## Regulatory Compliance and Local Restrictions

Deploying a media streaming platform in Saudi Arabia requires strict adherence to national regulatory frameworks governing public broadcasts, content moderation, data privacy, and religious assemblies.

![[4th.png]]

### GAMR Audiovisual Licensing

The primary regulator for media in the Kingdom is the **General Authority of Media Regulation (GAMR)**, formerly known as GCAM. Under the Audiovisual Media Law, any platform that hosts, distributes, or broadcasts video-on-demand or live streaming content must hold an **Audiovisual Media License**.

Operating a streaming app without this license is a serious violation, carrying potential administrative fines of up to **SAR 5 million** under current regulations, or up to **SAR 10 million** under draft Media Laws. Furthermore, all streamed content must strictly align with Saudi Arabia's social, cultural, and legal values. Content must conform to Shari'ah principles, respect political leadership, protect public order, and omit any vulgarity or prohibited promotions.

### CST Registration Thresholds

The **Communications, Space & Technology Commission (CST)** regulates digital communications platforms in Saudi Arabia. Video OTT platforms operating in the Kingdom that reach **35,000 or more active subscribers** must register with the CST.

Upon hitting this threshold, the platform is subject to an annual registration fee of **SAR 50,000**. This recurring fee must be factored into long-term financial planning as the platform scales.

### Ministry of Islamic Affairs Mosque Rules

Because the platform's core concept includes streaming mosque talks, it is subject to strict directives from the **Ministry of Islamic Affairs, Dawah and Guidance**. The Ministry enforces strict directives prohibiting the live transmission, recording, or broadcasting of congregational prayers (Salah) and the call to prayer (Adhan) inside mosques across all media formats.

To ensure compliance, the platform cannot allow open, unmoderated streaming from mosques. The application must implement the following controls:

1. **Scheduled Window Restraints:** Stream ingestion keys should only activate during pre-approved, non-prayer hours specifically scheduled for educational lectures, lessons, or sermons.
2. **Automated Audio Moderation:** Implement server-side audio analysis on incoming feeds. If the system detects prayer recitation or the Adhan, it must instantly trigger a stream-cutoff protocol.
3. **Manual Overrides:** Provide on-site operators and platform administrators with a "kill switch" in the control panel to instantly terminate any stream if the feed accidentally captures congregational prayer services.

### PDPL Compliance and Data Residency

The **Personal Data Protection Law (PDPL)** governs how personal user data, logs, and interaction records are managed in Saudi Arabia. PDPL mandates that personal user data and communication logs must be stored and processed within Saudi Arabia's borders.

Path 1 complies with this mandate by deploying all AWS resources (IVS, S3 buckets, user authentication databases) inside the AWS Riyadh Region (`me-central-2`). This ensures that all data residency requirements are met natively, avoiding the legal complexities of cross-border data transfers.

## Financial Complexity and Cost Projections

The primary financial risk of Path 1 is its linear, usage-based cost structure. Unlike self-hosted servers with fixed hardware costs, every additional hour of video ingested, every viewer connected, and every gigabyte of data stored directly increases the monthly cloud invoice.

### Financial Model Variables

The financial calculations below illustrate two distinct operational phases. These models assume standard 1080p video ingestion streaming at an average bitrate of 5 Mbps (equivalent to 2.25 GB of storage generated per hour of streaming). Output delivery is distributed as 80% HD (720p) and 20% SD (480p) streams.

For the Middle East and Africa (MEAA) region, estimated hourly delivery rates are modeled at $0.110 per HD hour and $0.055 per SD hour. S3 storage is priced at $0.023 per GB/month, and CloudFront egress for Middle East VOD delivery is priced at $0.085 per GB.

- **Scenario A: Initial Sandbox Phase (Al Khobar Pilot)**
    - Target operations: 1 to 5 streams per week, modeled at 4 streams per week (16 streams per month).
    - Stream duration: 2 hours per stream, totaling 32 input hours per month.
    - Viewer scale: Average of 100 concurrent viewers (CCU) per stream.
    - Average viewer watch duration: 50% (1 hour per viewer).
    - VOD consumption: Assuming 500 hours of archived playbacks per month.
    - Legacy logs: Initial migration of 100 hours of existing video files (~225 GB).
- **Scenario B: Scaled Regional Expansion**
    
    - Target operations: 25 streams per week, totaling 100 streams per month.
    - Stream duration: 2 hours per stream, totaling 200 input hours per month.
    - Viewer scale: Average of 1,500 CCU per stream.
    - Average viewer watch duration: 50% (1 hour per viewer).
    - VOD consumption: Assuming 10,000 hours of archived playbacks per month.
    - Cumulative storage (new + historical): Maintained at 2,000 GB.

### Scenario A Monthly Cost Breakdown (Al Khobar Sandbox)

The table below itemizes the monthly cloud expenses during the initial pilot phase in Al Khobar:

|**Billing Item**|**Quantitative Metrics**|**Unit Rate (USD)**|**Total Cost (USD)**|**Total Cost (SAR)**|
|---|---|---|---|---|
|**AWS IVS Live Input**|32 hours of Standard channel input|$2.00 / hour|$64.00|240.00|
|**AWS IVS HD Live Output**|1,280 hours delivered (80% of 1,600 hours)|$0.110 / hour|$140.80|528.00|
|**AWS IVS SD Live Output**|320 hours delivered (20% of 1,600 hours)|$0.055 / hour|$17.60|66.00|
|**S3 Storage (Live Archives)**|72 GB generated (32 hours × 2.25 GB/hr)|$0.023 / GB / month|$1.66|6.23|
|**S3 Storage (Legacy Logs)**|225 GB migrated (100 hours × 2.25 GB/hr)|$0.023 / GB / month|$5.18|19.43|
|**CloudFront VOD Egress**|1,125 GB transferred (500 hours VOD playback)|$0.085 / GB|$95.63|358.61|
|**IVS Chat Message Delivery**|50,000 sent, 5,000,000 delivered|Volumetric pricing|$55.00|206.25|
|**Estimated Monthly Total**|**-**|**-**|**$379.87**|**1,424.52**|

### Scenario B Monthly Cost Breakdown (Regional Expansion)

The table below itemizes the monthly cloud expenses as the platform scales regionally:

|**Billing Item**|**Quantitative Metrics**|**Unit Rate (USD)**|**Total Cost (USD)**|**Total Cost (SAR)**|
|---|---|---|---|---|
|**AWS IVS Live Input**|200 hours of Standard channel input|$2.00 / hour|$400.00|1,500.00|
|**AWS IVS HD Live Output**|120,000 hours delivered (80% of 150,000 hours)|$0.110 / hour|$13,200.00|49,500.00|
|**AWS IVS SD Live Output**|30,000 hours delivered (20% of 150,000 hours)|$0.055 / hour|$1,650.00|6,187.50|
|**S3 Storage (Active Archives)**|2,000 GB stored (Cumulative logs)|$0.023 / GB / month|$46.00|172.50|
|**CloudFront VOD Egress**|22,500 GB transferred (10,000 hours VOD playback)|$0.085 / GB|$1,912.50|7,171.88|
|**IVS Chat Message Delivery**|500,000 sent, 50,000,000 delivered|Volumetric pricing|$550.00|2,062.50|
|**Estimated Monthly Total**|**-**|**-**|**$17,758.50**|**66,594.38**|

### Financial Trade-Off Analysis

Comparing the cost profiles of Scenario A and Scenario B reveals a critical trend: **Path 1 lacks operational leverage**. While streaming hours scale up by approximately 6x, the total monthly bill increases by nearly **47x** (from $379.87 to $17,758.50). This disproportionate cost growth is driven by egress fees, with output delivery representing nearly 84% of the scaled budget.

At this scale, a monthly expenditure of over 66,000 SAR is a clear signal to evaluate transitioning from Path 1 to a hybrid architecture (Path 3) or local infrastructure (Path 2) to decoupling viewer growth from linear billing increases.

## Implementation Plan and Roadmap

To manage these technical, financial, and regulatory challenges, the project should follow a structured, phased rollout plan over a 12-month period.

The table below maps out the key phases of the implementation plan, including target durations, operational objectives, technical milestones, and regulatory deliverables:

|**Roadmap Phase**|**Target Duration**|**Operational Objectives**|**Technical Milestones**|**Regulatory Deliverables**|
|---|---|---|---|---|
|**Phase 1: Environment Setup & Sandboxing**|Months 1–2|Set up AWS development environment and establish local test venues.|Configure AWS Riyadh (`me-central-2`) services ; test RTMP/SRT ingestion pipelines.|Begin preparing GAMR license application documentation.|
|**Phase 2: App Development & Legacy Migration**|Months 3–4|Integrate video playback and interactive features; migrate legacy video logs.|Integrate the Amazon IVS SDK ; build chat features and timed metadata ; transcode legacy logs.|Submit official application to GAMR for the Audiovisual Media License.|
|**Phase 3: Beta Launch & Pilot Phase**|Months 5–8|Run a private beta with 500 local users; stream 1 to 5 events weekly in Al Khobar.|Deploy automated audio moderation systems ; verify edge performance via the Jeddah CloudFront node.|Secure GAMR license ; install stc Business Fiber at pilot venues.|
|**Phase 4: Public Scale-Up**|Months 9–10|Launch public app across the Eastern Province; scale to 15+ concurrent streaming venues.|Scale ingestion and edge caching ; optimize S3 storage using lifecycle policies.|Register platform with CST upon reaching 35,000 subscribers.|
|**Phase 5: Architectural Optimization**|Months 11–12|Audit cloud costs; evaluate transitioning to hybrid (Path 3) or local (Path 2) streaming models.|Build performance dashboard ; optimize client-side playback buffer strategies.|Ensure ongoing compliance with PDPL data privacy audits.|

## Strategic Conclusions

Path 1 provides an excellent approach for launching the educational streaming platform quickly and with low initial overhead. By utilizing fully managed cloud services in the AWS Riyadh region (`me-central-2`), the platform secures immediate compliance with local data residency regulations (PDPL) while eliminating the need for upfront server hardware investments.

However, the usage-based pricing model of Path 1 represents a significant financial challenge as the platform scales. Egress and message delivery costs grow linearly with viewership, meaning that high-volume regional adoption will lead to substantial monthly cloud invoices.

Therefore, Path 1 is highly viable as a launchpad for the sandbox and pilot phases in Al Khobar. As the user base grows toward the 35,000-subscriber mark, the platform should plan to transition to a hybrid architecture (Path 3). This hybrid approach allows the platform to utilize local servers for high-volume video distribution while keeping core interactive and control features in the cloud, combining cost efficiency with operational reliability.


----

# Architectural, Financial, and Regulatory Feasibility of Self-Hosted/In-House Infrastructure (Path 2)

This report evaluates the technical viability, structural complexity, financial parameters, and regulatory conditions of deploying a fully self-hosted/in-house streaming platform—designated as Path 2—for an educational streaming platform starting in the Al Khobar region of Saudi Arabia. Under Path 2, the platform shifts away from managed cloud services, taking direct ownership of physical, custom-built enterprise servers running open-source streaming engines.   

## Technical Architecture of the Self-Hosted Media Pipeline

The self-hosted media pipeline requires designing, building, and maintaining the end-to-end processing and delivery stack locally.

![[234.png]]

### Physical Bare-Metal Server Configuration

To reliably process multi-bitrate streams, database records, and WebSocket client connections, Path 2 must deploy enterprise-grade server hardware. The baseline hardware specification designed for this architecture is the **Dell PowerEdge R760 (2U rack server)**:

- **Processor:** Dual 4th Generation Intel Xeon Scalable processors (providing up to 48 physical cores and 96 threads per server to manage system overhead, core processes, and API routing).
- **Memory:** 256GB DDR5 ECC RAM (critical for holding temporary live streaming segment buffers, memory cache databases, and running internal RAM disks).
- **Local Storage Array:** 2x 960GB SATA boot SSDs configured in RAID 1 (for operating system and service redundancy) plus 4x 3.84TB enterprise NVMe SSDs configured in RAID 5 (providing roughly 11.5TB of high-speed, fault-tolerant local storage for newly recorded streams and migrated logs).
- **Network Interface:** Broadcom 57416 Dual Port 10GbE Base-T PCIe network adapters, ensuring the physical server can ingest and deliver massive data packets without network port throttling.

### GPU Hardware-Accelerated Transcoding

Relying on standard CPUs to transcode multiple live adaptive bitrate (ABR) video feeds is highly inefficient and risks processor lockup. To achieve high-throughput, cost-effective media processing, the server must be equipped with an **Nvidia L4 Tensor Core GPU** (24GB GDDR6 memory, low-profile PCIe form factor, drawing only 72W of power).

The Nvidia L4 contains dedicated hardware video encoders (NVENC) and decoders (NVDEC). Benchmarks show that while a dual-socket high-end Intel CPU node handles 1080p transcoding at roughly 1,034 frames per second (FPS), a single Nvidia L4 GPU delivers a total throughput of **6,200 FPS at 1080p**. This massive performance margin allows a single Nvidia L4 card to easily process over 15 concurrent 1080p live streams into full ABR ladders (1080p, 720p, 480p, 360p) in real time with minimal CPU utilization.

## Technical and Software Complexity of the DIY Stack

Instead of using proprietary cloud services, Path 2 requires building, optimizing, and maintaining the entire media processing and interactive backend stack from scratch.

### Media Core: Simple Realtime Server (SRS)

**SRS** is chosen as the central media routing engine due to its superior protocol support, multi-threading architecture, and low-latency performance. Operating on a single-process lightweight thread model, SRS can support up to 3,000 concurrent live player connections on a single CPU core.

SRS provides native, in-engine protocol translation:

- **Ingest:** Accepts RTMP, RTMPS, and SRT streams from local encoders.
- **Ultra-Low Latency Playback:** SRS delivers streams over WebRTC with an end-to-end latency of only **150 milliseconds**, which is crucial for real-time engagement. For standard scale-out playback, it translates incoming feeds to HTTP-FLV (latency ~3 seconds) or LL-HLS/HLS (latency ~5 seconds).

### Storage Bottleneck Mitigation: RAM Disk / tmpfs

HLS live streaming relies on writing thousands of tiny index files (`.m3u8`) and video chunks (`.ts`) to disk every second. Writing these directly to physical SSDs causes disk I/O bottlenecks and will rapidly wear out enterprise flash storage due to high write-amplification.

Path 2 mitigates this risk by configuring a virtual RAM disk using the Linux `tmpfs` file system. A portion of the system's physical DDR5 memory is isolated and mounted as a local directory:

Bash

```
sudo mkdir -p /mnt/ramdisk
sudo mount -t tmpfs -o size=8G tmpfs /mnt/ramdisk
```

By configuring SRS or Nginx to output all active HLS segments directly to `/mnt/ramdisk`, read and write speeds operate at memory-bus speeds. Once a stream completes, a background script compresses and copies the finalized media chunks to the persistent NVMe RAID array for permanent archival, ensuring zero disk wear during live broadcasts.

### Playback Scalability: Nginx Edge Caching

To prevent the core SRS server from running out of network capacity when hundreds of viewers fetch HLS files simultaneously, the system uses **Nginx Edge Caching**. Nginx is deployed as a local reverse proxy cache in front of SRS.

When viewers request HLS segments, they hit Nginx. Nginx serves the segment directly from its `tmpfs` memory cache. This architecture ensures that regardless of how many concurrent viewers access the stream, the SRS media engine only processes a single stream segment fetch.

Nginx

```
# Nginx Cache Configuration for HLS Segments
proxy_cache_path /mnt/ramdisk/nginx-cache levels=1:2 keys_zone=hls_cache:10m max_size=2g inactive=10m;

server {
    listen 80;
    location ~ \.(ts)$ {
        proxy_pass http://127.0.0.1:8080;
        proxy_cache hls_cache;
        proxy_cache_valid 200 302 10m;
        add_header X-Cache-Status $upstream_cache_status;
    }
}
```

### Self-Hosted Identity and Features Stack

To replace the serverless database and auth utilities used in cloud environments, Path 2 runs a localized, Docker-managed application stack on the primary bare-metal server:

1. **Identity & Access Control (Keycloak):** An open-source Identity and Access Management (IAM) solution deployed via Docker on the server, handling user registrations, password hashing, and role permissions (Lecturer, Student, Admin).
2. **Database Core (PostgreSQL):** Running locally in high-availability mode to manage the structured catalog of stream metadata, schedules, user profiles, and VOD links.
3. **Real-Time Interactivity Engine:** Built using a dedicated **Node.js WebSocket server** backed by an in-memory **Redis** cache. Viewers establish WebSocket connections directly to the Node.js container. Clapping gestures, live polls, and user questions are processed in memory within Redis, ensuring real-time UI updates under heavy traffic without stressing the primary relational database.

## Local ISP Infrastructure and Physical Deployment Options

The viability of Path 2 depends heavily on where the physical server is deployed and how it connects to the internet.

### Network Egress Calculation for Self-Hosting

When running a local server, the local connection is no longer just for uploading (ingesting) a single feed. The server's connection must act as the primary upload line to distribute video to every viewer simultaneously. This is the **Network Egress Bottleneck**.

To calculate the required upload speed on the server side:

Required Server Egress Bandwidth=Target Video Bitrate×Concurrent Viewers×1.2

The calculation incorporates a standard network safety overhead factor of 1.2× to account for TCP retransmission packets, network protocol headers, and sudden frame complexity spikes. Using a standard 1080p stream bitrate of 3.0 Mbps:

- **Scenario A (Al Khobar Pilot - 100 CCU):** The physical upload speed required on the server-side is calculated as: 3.0 Mbps x 100 viewers x 1.2 = 360 Mbp
- **Scenario B (Regional Expansion - 1,500 CCU):** The physical upload speed required on the server-side is calculated as: 3.0 Mbps x 1,500 viewers x 1.2 = 5,400 Mbps (5.4 Gbps

### Option A: In-House Deployment (Office-Hosted)

Placing the Dell PowerEdge server directly in an Al Khobar office or local headquarters represents the most basic physical deployment mode.

#### Network Costs

Standard asymmetrical commercial connections (e.g., stc Fiber Link 1 Gbps, costing SAR 1,724/month) only provide **300 Mbps of upload speed**. As proven by the egress equation, this connection will fail and cause buffering once more than 80 users connect to the stream.   

To host the pilot phase safely in-house with guaranteed bandwidth, the venue must buy a **Dedicated Internet Access (DIA)** line. DIA offers 1:1 symmetrical bandwidth with robust corporate Service Level Agreements (SLAs). However, DIA pricing in Saudi Arabia is exceptionally high:

- **stc DIA 10 Mbps:** SAR 4,943.85 / month
- **stc DIA 40 Mbps:** SAR 16,098.85 / month
- **stc DIA 100 Mbps:** SAR 35,418.85 / month
- **stc DIA 200 Mbps:** SAR 62,167.85 / month
- **Salam DIA 50 Mbps:** SAR 58,995 / month
- **Salam DIA 250 Mbps:** SAR 221,375 / month

This pricing shows that true business DIA makes hosting a high-capacity server inside a local office financially unviable, costing far more than managed cloud services.

#### Power and Utilities

If running in-house, the server will operate 24/7. Commercial electricity pricing in Saudi Arabia, regulated by the Saudi Electricity Regulatory Authority (ECRA), is set at:

- **Up to 6,000 kWh per month:** 22 halalas per kWh (0.22 SAR).
- **Exceeding 6,000 kWh per month:** 32 halalas per kWh (0.32 SAR).

A Dell PowerEdge R760 with an Nvidia L4 GPU draws an average continuous system load of roughly 550 Watts (0.55 kW) under active transcoding and delivery conditions.

To calculate the monthly power cost of a single server:

Power Usage=0.55 kW×24 hours/day×30 days=396 kWh/month

Power Cost=396 kWh×0.22 SAR=87.12 SAR/month per server

While the electricity cost of the server is low (SAR 87.12 per month), the venue must also run dedicated 24/7 air conditioning to prevent the hardware from overheating, which typically triples local power consumption.

### Option B: Local Colocation (Data Center-Hosted)

Instead of keeping hardware in an office, Path 2 can utilize local carrier-neutral data centers. The hardware is installed in a secure, climate-controlled, high-bandwidth environment.

#### Data Center Providers in Saudi Arabia

The market is led by stc, Mobily, Equinix, and Gulf Data Hub. Physical rack space can be rented inside major carrier nodes in Riyadh, Jeddah, or Dammam.

#### Colocation Pricing

Data center colocation in Saudi Arabia is priced as a premium enterprise service:

- **stc Cloud Colocation (Riyadh ITCC Facility):** Renting a single standard 42U cabinet starts at **SAR 29,900 / month** (VAT inclusive). A setup fee of SAR 34,500 is charged upfront.
- **stc Cloud Colocation (Jeddah Tier IV Facility):** Renting a single cabinet space costs **SAR 25,300 / month** (VAT inclusive).
- **Includes:** Redundant A/B power feeds, physical security, precision cooling, and an initial set of public IP addresses.
- **Excludes:** Bandwidth. Connecting the cabinet directly to high-capacity internet links or telecom cross-connects (Data Center Direct Links) carries additional recurring charges based on per-Mbps metrics.

## Regulatory Compliance and Local Restrictions

While cloud paths offload data sovereignty compliance to managed service providers, Path 2 places all regulatory burdens directly on our operations team.

### GAMR Audiovisual Licensing

The primary regulator for media in the Kingdom is the **General Authority of Media Regulation (GAMR)**, formerly known as GCAM. Under the Audiovisual Media Law, any platform that hosts, distributes, or broadcasts video-on-demand or live streaming content must hold an **Audiovisual Media License**.   

Operating a streaming app without this license is a serious violation, carrying potential administrative fines of up to **SAR 5 million** under current regulations, or up to **SAR 10 million** under draft Media Laws. Because we own the physical server hosting the media files under Path 2, we are directly liable for any unapproved, copyrighted, or non-compliant content sitting on our hard drives. Content must strictly conform to Shari'ah principles, respect political leadership, protect public order, and omit any vulgarity.   

### CST Registration Thresholds

The **Communications, Space & Technology Commission (CST)** regulates digital communications platforms in Saudi Arabia. Video OTT platforms operating in the Kingdom that reach **35,000 or more active subscribers** must register with the CST.

Upon hitting this threshold, the platform is subject to an annual registration fee of **SAR 50,000**. This recurring fee must be factored into long-term financial planning as the platform scales.   

### Ministry of Islamic Affairs Mosque Rules

Because the platform's core concept includes streaming mosque talks, it is subject to strict directives from the **Ministry of Islamic Affairs, Dawah and Guidance**. The Ministry enforces strict directives prohibiting the live transmission, recording, or broadcasting of congregational prayers (Salah) and the call to prayer (Adhan) inside mosques across all media formats.

To ensure compliance under Path 2, we must build a centralized manual control dashboard:

1. **Scheduled Ingestion Blocks:** Stream ingestion keys must be programmatically locked. They should only activate during pre-approved, non-prayer hours specifically scheduled for educational lessons or sermons.
2. **Automated Cache Clearing:** If a stream accidentally captures a congregational prayer service, administrators must be able to instantly terminate the stream and run a script to completely wipe the RAM caching directory (`/mnt/ramdisk/`) to prevent any cached chunks from being distributed or archived on local storage.

### PDPL Compliance and Physical Security

Under the **Personal Data Protection Law (PDPL)**, because we are hosting the user databases (credentials, profiles, chat history) on-premises, we must implement strict physical data security controls.

If servers are kept in-office, the server room must have biometric access controls, detailed physical guest logs, and encrypted drive arrays to prevent physical database theft. Storing user data on unencrypted local office drives is a major compliance risk that can lead to heavy administrative fines.   

## Financial Complexity and Cost Projections

Unlike pay-as-you-go cloud models, Path 2 requires heavy upfront capital investment (CAPEX) followed by fixed monthly infrastructure costs (OPEX). The financial models below assume the purchase of standard, brand-new enterprise-grade equipment.

### Scenario A: Initial Sandbox Phase (Al Khobar Office Pilot)

- **Operations:** 16 streams per month, 100 concurrent viewers (CCU).   
- **Deployment:** Dell R760 server placed inside our Al Khobar office, connected to a business-grade fiber line with maximum upload capacity.

#### Upfront Capital Expenditure (CAPEX)

|Physical Asset|Specifications|Vendor Rate (SAR)|
|---|---|---|
|**Dell PowerEdge R760 Server**|Single CPU (24 Cores), 64GB DDR5 RAM, 2x 480GB boot SSDs|20,949|
|**Nvidia L4 Transcoding GPU**|24GB GDDR6 dedicated hardware video processing|18,800|
|**Storage RAID Array**|4x 4TB Enterprise SAS HDDs configured in RAID 5|6,000|
|**Rack and Power Backup**|2U server rack, 1500VA UPS backup battery|3,500|
|**Total CAPEX**|**Complete On-Premises Server Build**|**49,249**|

#### Ongoing Monthly Operational Expenditure (OPEX)

|Service Item|Quantitative Metrics|Unit Rate (SAR)|Total Cost (SAR)|
|---|---|---|---|
|**stc Fiber Link 1 Gbps**|1 Gbps download / 300 Mbps upload commercial line|1,724 / month|1,724.00|
|**Server Electricity**|396 kWh consumed per month|0.22 / kWh|87.12|
|**AC Auxiliary Cooling Power**|800 kWh consumed per month|0.22 / kWh|176.00|
|**Total Monthly OPEX**|**In-Headquarters Hosting**|**-**|**1,987.12**|

  

### Scenario B: Scaled Regional Expansion (Data Center Colocation)

- **Operations:** 100 streams per month, 1,500 concurrent viewers (CCU) across the Eastern Province.   
- **Deployment:** A dedicated private rack deployed in stc's local colocation data center to ensure high-capacity egress bandwidth and redundant power.

#### Upfront Capital Expenditure (CAPEX)

|Physical Asset|Specifications|Vendor Rate (SAR)|
|---|---|---|
|**3x Dell PowerEdge R760 Servers**|Dual Intel Xeon, 128GB RAM, enterprise NVMe storage|165,000|
|**3x Nvidia L4 Transcoding GPUs**|Dedicated GPU for hardware transcoding on each node|56,400|
|**Enterprise Network Hardware**|10G managed switches, local rack PDUs, rack Rails|18,000|
|**Professional Installation**|Physical datacenter installation and configuration fee|10,000|
|**Total CAPEX**|**Complete Data Center Infrastructure Deployment**|**249,400**|

#### Ongoing Monthly Operational Expenditure (OPEX)

|Service Item|Quantitative Metrics|Unit Rate (SAR)|Total Cost (SAR)|
|---|---|---|---|
|**stc Cloud Colocation Fee**|1x full 42U rack space, including power allocation|29,900 / month|29,900.00|
|**Datacenter Internet Link**|Symmetrical 1 Gbps Dedicated Port (Unmetered)|15,000 / month|15,000.00|
|**Maintenance Fund**|System parts replacement & hardware depreciation reserve|2,500 / month|2,500.00|
|**Total Monthly OPEX**|**Enterprise Colocation Hosting**|**-**|**47,400.00**|

## Integration and Migration of Legacy Logs

To enable access to existing stream logs, Path 2 must build a localized file ingestion and transcoding pipeline:

![[123.png]]

1. **Batch Ingestion:** The pre-recorded stream logs are transferred directly to the server's local high-speed NVMe storage array (configured in RAID 5).
2. **Localized Transcoding:** A background Python script triggers a localized **FFmpeg pipeline**. The script utilizes `h264_nvenc` or `hevc_nvenc` commands to offload processing to the Nvidia L4 GPU:
Bash
```
   ffmpeg -y -vsync 0 -hwaccel cuda -hwaccel_output_format cuda -i input.mp4 \
    -c:a aac -b:a 128k \
    -c:v h264_nvenc -preset p4 -b:v 3000k -s 1280x720 output_720p.mp4    
```

This processes the legacy files into standardized HLS folders containing   multi-bitrate ABR ladders (1080p, 720p, 480p, and 360p).

3. **Database Cataloging:** Once transcoding finishes, the script inserts a new row into the local PostgreSQL database containing the video ID, metadata (lecturer, topic, date), and the path to the main playlist file (`.m3u8`). The frontend application queries this database to present a unified catalog of live and archived VOD logs.

## 12-Month Implementation Plan and Road Map

Because Path 2 involves physical hardware acquisition and localized software orchestration, the project timeline requires a structured 12-month roadmap.   

|Roadmap Phase|Target Duration|Operational Objectives|Technical Milestones|Regulatory Deliverables|
|---|---|---|---|---|
|**Phase 1: Procurement & Setup**|Months 1–2|Purchase bare-metal servers, GPUs, and install basic networking.|Unbox and rack hardware; install Linux OS, configure local RAID 5 arrays.|Prepare GAMR license documentation and address physical data safety rules.|
|**Phase 2: Software Orchestration**|Months 3–4|Set up the media server software, database, and identity system.|Compile SRS with WebRTC support; mount memory RAM disks (`tmpfs`).|Submit official license application to GAMR.|
|**Phase 3: Beta Testing**|Months 5–8|Run private beta with 1 to 5 weekly streams; stream logs archived locally.|Integrate Nginx Reverse Proxy Cache; test local FFmpeg NVENC transcoding scripts.|Secure GAMR license; verify schedule-gates for mosque talks.|
|**Phase 4: Data Center Migration**|Months 9–10|Move servers to stc local colocation facility to resolve upload bottlenecks.|Re-route network endpoints; test unmetered 1 Gbps data center connection.|Register platform with CST upon reaching 35,000 subscribers.|
|**Phase 5: Platform Optimization**|Months 11–12|Perform load testing to prepare for scaling across the Eastern Province.|Run stress tests using `srs-bench` Docker containers; audit local PostgreSQL database indices.|Perform physical and digital PDPL security audits.|

## Strategic Conclusions

Path 2 provides a highly sustainable approach for teams looking to bypass recurring monthly cloud bills and establish complete sovereignty over their media delivery. Taking direct ownership of physical hardware gives us complete control over our storage capacity, transcoding pipelines, and data security, while allowing us to stream to thousands of concurrent users at a flat, predictable monthly rate.

However, this model demands significant technical expertise and carries a high initial entry barrier. We must manage server physical safety, OS hardening, manual network caching, and complex local media configurations ourselves. Additionally, physical hosting inside Al Khobar offices is severely limited by upload speeds, making **local data center colocation** an eventual necessity as the platform scales.

Therefore, Path 2 is highly viable if we possess strong in-house system administration skills and have the capital to invest in upfront hardware and data center rack space. This approach guarantees long-term cost efficiency and complete data compliance within Saudi Arabia.

---

# Architectural, Financial, and Regulatory Feasibility of Hybrid Cloud-Local Infrastructure (Path 3)

This report evaluates the technical viability, structural complexity, financial parameters, and regulatory conditions of deploying a hybrid cloud-local infrastructure—designated as Path 3—for an educational streaming platform starting in the Al Khobar region of Saudi Arabia. Under Path 3, the platform splits workloads between **on-premises edge systems** (for local capture, hardware-accelerated transcoding, and interactive metadata synchronization) and **managed cloud resources** (for secure object storage and high-throughput Content Delivery Network distribution).

## Technical Architecture of the Hybrid Media Pipeline

The hybrid media pipeline maximizes local edge efficiency while offloading scale-out distribution to public cloud regions based inside Saudi Arabia.

![[121.png]]
### On-Premises Ingest and GPU Transcoding (The Local Piece)

The ingest process starts at our venues in Al Khobar, where physical audio-video feeds are captured by high-definition cameras. Instead of transmitting high-bitrate raw feeds directly to a cloud processing suite—which consumes massive upload bandwidth—the feeds are routed locally over a local area network to an on-premises **Dell PowerEdge R760 server**.

The local server is configured with:

- **Processor:** Single Intel Xeon Gold 4419 (24 Cores / 48 Threads) to manage media routing, local database lookups, and system tasks.
- **Memory:** 128GB DDR5 ECC RAM to hold memory buffers and execute background tasks.
- **GPU Accelerator:** 1x **Nvidia L4 Tensor Core GPU** (24GB GDDR6 memory, 72W power envelope).

The local server runs **Simple Realtime Server (SRS)** to ingest the RTMP/SRT streams from on-site encoders. SRS uses the Nvidia L4’s dedicated hardware encoders (NVENC) via FFmpeg integrations to decode the incoming 1080p source feed and instantly transcode it into a multi-bitrate Adaptive Bitrate (ABR) HLS ladder (1080p at 4.5 Mbps, 720p at 2.5 Mbps, 480p at 1.2 Mbps, and 360p at 0.8 Mbps).

### Storage Bottleneck and SSD Wear Mitigation

To prevent severe disk write-amplification and write bottlenecks, the local server isolates a portion of its physical DDR5 memory to mount a **RAM disk (`tmpfs`)** directory:

Bash

```
sudo mkdir -p /mnt/ramdisk
sudo mount -t tmpfs -o size=8G tmpfs /mnt/ramdisk
```

SRS writes active HLS segments (`.ts`) and index files (`.m3u8`) directly to `/mnt/ramdisk` at memory-bus speeds, avoiding hard drive friction.

### S3 Backhaul and Cloud CDN Delivery (The Cloud Piece)

Instead of hosting the viewer traffic directly off our local office server—which creates severe upload bandwidth bottlenecks—Path 3 routes distribution entirely through the cloud.

A lightweight background daemon (running `rclone` or integrated SRS upload hooks) continuously monitors the local `/mnt/ramdisk` directory. The moment a new `.ts` segment file is written locally, the daemon uploads it over the local business fiber connection directly to an **Amazon S3 bucket** located in the **AWS Riyadh region (`me-central-2`)**.

Once stored in S3, delivery is accelerated by **Amazon CloudFront**. CloudFront utilizes its **Jeddah Edge Node** to fetch files from S3, cache them, and deliver them to users across the Eastern Province. This design ensures that regardless of whether 100 or 30,000 viewers are watching, our on-premises server only needs enough upload bandwidth to push a single set of transcoded ABR segments to the S3 bucket.

## Technical and Software Complexity of the Hybrid Architecture

Path 3 achieves high structural reliability, but requires orchestration across both local bare-metal servers and cloud-native storage APIs.

|**Feature Dimension**|**Local Edge Responsibility**|**Cloud Platform Responsibility**|
|---|---|---|
|**Ingest & Capture**|Handles camera feeds, captures RTMP/SRT streams via SRS.|Idle during ingest.|
|**ABR Transcoding**|Offloads processing to local Nvidia L4 hardware-accelerated NVENC.|Idle; transcoded segments are received pre-packaged.|
|**Media Caching**|Writes active HLS chunks to a virtual memory RAM disk (`tmpfs`).|Amazon S3 hosts the master manifests and segment archives.|
|**Egress Delivery**|Uploads a single, constant ABR ladder (approx. 9.0 Mbps) to S3.|CloudFront delivers dynamic caching and handles massive concurrency at the edge.|
|**Interactivity & Sockets**|Manages localized interactive triggers and matches ID3 tags.|Node.js/Redis containers hosted on AWS EC2 in Riyadh manage high-volume WebSockets.|

## Local ISP Infrastructure and Physical Deployment Options

Because Path 3 offloads video egress to CloudFront, local office network upload demands are drastically reduced compared to fully self-hosted models.

### Local Ingestion Bandwidth Calculations

Our local server must upload a single, complete transcoded ABR ladder to the S3 bucket in Riyadh. The cumulative bitrate of our transcoded ladder is calculated as follows:

$$\text{ABR Ladder Bitrate}=4.5\text{ Mbps (1080p)}+2.5\text{ Mbps (720p)}+1.2\text{ Mbps (480p)}+0.8\text{ Mbps (360p)}=9.0\text{ Mbps}$$

We apply a network safety overhead factor of $1.5\times$ to account for TCP retransmission packets, packet headers, and network synchronization jitter:

$$\text{Required Local Upload Speed}=9.0\text{ Mbps}\times1.5=13.5\text{ Mbps}$$

This shows that a standard business-grade broadband fiber line, such as the **stc Fiber Link 100** (offering 100 Mbps download and **20 Mbps upload** for **SAR 344 / month**), is more than sufficient to handle our ingestion needs.

This completely eliminates the need for expensive dedicated internet access (DIA) lines, such as stc’s 100 Mbps DIA line (costing **SAR 35,418 / month**), which is required in Path 2 to handle concurrent viewers locally.

### Physical Server Deployment

Since Path 3 offloads scale-out distribution to the cloud, our local server does not require a highly redundant data center rack space (saving **SAR 29,900 / month** in colocation fees).

Instead, the Dell PowerEdge R760 server is placed directly inside our Al Khobar office or headquarters in a clean, air-conditioned room.

#### On-Headquarters Power and Utility Pricing

The server runs 24/7. Commercial electricity pricing in Saudi Arabia, regulated by the Saudi Electricity Regulatory Authority (ECRA), is set at **22 halalas (0.22 SAR) per kWh** for consumption up to 6,000 kWh per month.

A Dell PowerEdge R760 server drawing a continuous system load of 550 Watts (0.55 kW) during active transcoding consumes:

$$\text{Monthly Power Usage}=0.55\text{ kW}\times24\text{ hours/day}\times30\text{ days}=396\text{ kWh/month}$$

$$\text{Monthly Power Cost}=396\text{ kWh}\times0.22\text{ SAR}=87.12\text{ SAR/month per server}$$

To ensure hardware health, the server room must have continuous air conditioning, which draws roughly 800 kWh per month, adding **SAR 176.00** to our utility bill.

## Regulatory Compliance and Local Restrictions

Because Path 3 processes media locally and distributes it via cloud edge nodes, it must comply with strict national regulatory frameworks.

### Ministry of Islamic Affairs Mosque Rules

The Ministry of Islamic Affairs, Dawah, and Guidance prohibits live-streaming, recording, or broadcasting congregational prayers (Salah) and the call to prayer (Adhan) inside mosques across all media formats.

Under Path 3, we enforce compliance programmatically on our local edge server:

1. **Local Audio Analysis:** A script running on our local SRS server monitors the incoming audio feed. If it detects prayer recitation, it triggers an instant stream-cutoff protocol.
2. **Instant Local Purge:** When a cutoff is triggered, a script immediately terminates the `rclone` S3 sync daemon, drops the RTMP ingest connection, and completely wipes the local `/mnt/ramdisk/` folder. This ensures that no cached segments can be uploaded to S3, protecting the platform from accidental broadcast violations.

### GAMR Audiovisual Licensing

The platform must secure an **Audiovisual Media License** from the **General Authority of Media Regulation (GAMR)**, formerly known as GCAM.

Because video files are transcoded on our local server and immediately uploaded to a cloud S3 bucket, our platform remains fully liable for all media content stored on our cloud accounts. Content must strictly conform to Shari'ah principles, protect public order, and respect national values. Operating without a license carries administrative fines of up to **SAR 5 million**.

### PDPL Compliance and Data Residency

The **Personal Data Protection Law (PDPL)** requires that personal user data and communication logs are stored and processed within Saudi Arabia.

Path 3 natively complies with PDPL:

- **Personal Databases:** User profiles, authentication credentials, and chat records are stored in a local PostgreSQL database on our physical office server.
- **Video Storage:** Transcoded media files are backhauled entirely to S3 buckets inside the AWS Riyadh region (`me-central-2`), ensuring all video recordings (which may contain faces and are treated as personal data) remain strictly inside Saudi borders.

## Financial Complexity and Cost Projections

Path 3 combines a small upfront capital investment (CAPEX) for the local server with a scalable, usage-based cloud operational cost (OPEX).

Our financial models assume a standard 1080p stream bitrate of 4.5 Mbps (generating ~2.25 GB of data per hour). Video delivery is handled via CloudFront Middle East edge nodes, with egress costs calculated at a blended rate of **SAR 0.32 per GB ($0.085 USD/GB)**.

### Scenario A: Initial Sandbox Phase (Al Khobar Pilot)

- **Operations:** 16 streams per month, 100 concurrent viewers (CCU).
- **Video Egress Volume:** 100 viewers x 1 hour average watch x 16 streams x 1.5 GB/hour = **2,400 GB (2.4 TB)** of CDN data transfer.

#### Upfront Capital Expenditure (CAPEX)

|**Physical Asset**|**Specifications**|**Vendor Rate (SAR)**|
|---|---|---|
|**Dell PowerEdge R760 Server**|Single Intel Xeon (24 Cores), 128GB DDR5 RAM, 2x 480GB Boot SSDs|20,949|
|**Nvidia L4 Transcoding GPU**|24GB GDDR6 dedicated hardware video processing|18,800|
|**Edge Hardware Accessories**|2U server cabinet, 1500VA UPS backup battery|3,500|
|**Total CAPEX**|**Hybrid Ingestion Server Setup**|**43,249**|

#### Ongoing Monthly Operational Expenditure (OPEX)

|**Service Item**|**Quantitative Metrics**|**Unit Rate (SAR)**|**Total Cost (SAR)**|
|---|---|---|---|
|**stc Fiber Link 100**|100 Mbps download / 20 Mbps upload business fiber|344 / month|344.00|
|**Server Power & Cooling**|396 kWh server power + 800 kWh AC power|0.22 / kWh|263.12|
|**Amazon S3 Storage**|128 GB active HLS video log storage|0.086 / GB / month|11.00|
|**CloudFront Egress**|2,400 GB delivered to Middle East viewers|0.32 / GB|768.00|
|**Total Monthly OPEX**|**Al Khobar Sandbox Phase**|**-**|**1,386.12**|

### Scenario B: Scaled Regional Expansion

- **Operations:** 100 streams per month, 1,500 concurrent viewers (CCU).
- **Video Egress Volume:** 1,500 viewers x 1 hour average watch x 100 streams x 1.5 GB/hour = **225,000 GB (225 TB)** of CDN data transfer.

#### Upfront Capital Expenditure (CAPEX)

|**Physical Asset**|**Specifications**|**Vendor Rate (SAR)**|
|---|---|---|
|**3x Dell PowerEdge R760 Servers**|Shared local core setups across multiple venues|62,847|
|**3x Nvidia L4 Transcoding GPUs**|GPU transcode engines for concurrent regional streams|56,400|
|**Total CAPEX**|**Regional Multi-Venue Setup**|**119,247**|

#### Ongoing Monthly Operational Expenditure (OPEX)

|**Service Item**|**Quantitative Metrics**|**Unit Rate (SAR)**|**Total Cost (SAR)**|
|---|---|---|---|
|**3x stc Fiber Link 100**|Active upload connections across 3 Al Khobar venues|344 / month per line|1,032.00|
|**Power & Cooling (3 Nodes)**|3,588 kWh total power consumed per month|0.22 / kWh|789.36|
|**Amazon S3 Storage**|2,000 GB (2 TB) active storage in Riyadh Region|0.086 / GB / month|172.50|
|**CloudFront Egress**|225,000 GB delivered to Middle East viewers|0.28 / GB (Volume Tier)|63,000.00|
|**Total Monthly OPEX**|**Regional Expansion Phase**|**-**|**64,993.86**|

## Integration and Migration of Legacy Logs

Path 3 handles the migration of our existing video logs through a highly automated, local-to-cloud batch processing pipeline:

![[6th.png]]

1. **Local Batch Transcoding:** We copy our raw legacy video files directly to the local Dell R760 server. We execute a local batch script that uses FFmpeg and the Nvidia L4’s hardware transcoding blocks to convert files into standardized HLS directories:

Bash

```
    ffmpeg -y -vsync 0 -hwaccel cuda -hwaccel_output_format cuda -i legacy_file.mp4 \
      -c:a aac -b:a 128k \
      -c:v h264_nvenc -preset p4 -b:v 3000k -s 1280x720 output_720p.mp4
```

2. **Automated S3 Upload:** Once transcoded, an automated script uses `rclone` to push the completed HLS folders directly to our Amazon S3 bucket in the Riyadh region (`me-central-2`).
3. **Unified Database Indexing:** The script writes the metadata for each migrated video (such as Title, Speaker, Date, and its CloudFront URL) directly to our local PostgreSQL database. When a user opens the app, the interface queries the database, showing both legacy archives and newly recorded streams in a unified catalog.

## 12-Month Implementation Plan and Road Map

Building the hybrid infrastructure follows a structured 12-month roadmap, aligning physical server acquisition with cloud API configurations.

|**Roadmap Phase**|**Target Duration**|**Operational Objectives**|**Technical Milestones**|**Regulatory Deliverables**|
|---|---|---|---|---|
|**Phase 1: Local Setup**|Months 1–2|Purchase bare-metal servers, GPUs, and install local networking.|Set up local RAID arrays; configure SRS and mount `tmpfs` RAM disks.|Begin preparing GAMR license application documentation.|
|**Phase 2: Cloud Setup**|Months 3–4|Set up AWS services in Riyadh; build local-to-cloud upload sync daemons.|Configure S3 buckets and CloudFront ; test upload scripts.|Submit official application to GAMR for the Audiovisual Media License.|
|**Phase 3: Beta Launch**|Months 5–8|Run private beta with 1 to 5 weekly streams.|Verify ABR playback performance via CloudFront's Jeddah edge.|Secure GAMR license ; implement automated prayer stream block mechanisms.|
|**Phase 4: Scaling**|Months 9–10|Launch public app; support multiple concurrent streaming venues.|Scale ingest nodes; optimize S3 storage costs using automated lifecycle policies.|Register platform with CST upon reaching 35,000 active subscribers.|
|**Phase 5: Optimization**|Months 11–12|Run performance audits to prepare for expansion across the Eastern Province.|Optimize on-premises GPU transcode configurations; run load tests using `srs-bench`.|Perform physical and digital PDPL security audits.|

## Strategic Conclusions

Path 3 represents an exceptionally balanced, highly viable operational strategy for our educational streaming platform. By handling live transcoding locally on an on-premises Dell PowerEdge server with an Nvidia L4 GPU, we completely bypass expensive cloud-live-transcoding fees.

Simultaneously, by immediately backhauling transcoded segments to Amazon S3 in Riyadh and distributing them via Amazon CloudFront, we completely decouple our local network from viewer egress demands. This allows us to run our venues on standard, low-cost commercial fiber connections rather than expensive, dedicated corporate lines.

Additionally, this hybrid approach provides robust local control, allowing us to implement instant programmatic stream-cutoff mechanisms on our on-premises servers to fully comply with Ministry of Islamic Affairs guidelines.

Therefore, Path 3 is the **most technically and financially viable path** for the platform. It combines the low capital cost and ease of deployment of cloud-native systems with the performance and security advantages of dedicated physical hardware.

---

# Feasibility, Architectural, and Regulatory Analysis of the "Hacked" Infrastructure (Path 4)

This report evaluates the technical viability, structural complexity, financial parameters, and regulatory conditions of deploying a highly optimized, extremely cost-effective "hacked" infrastructure—designated as Path 4—for an educational streaming platform starting in the Al Khobar region of Saudi Arabia. Under Path 4, the platform leverages existing consumer web services, open-source single-binary backends, and lightweight WebSocket frameworks. This approach shifts video processing, content delivery networks (CDNs), and file archiving workloads completely away from expensive enterprise contracts, reducing infrastructure operating expenses (OPEX) to near zero.

## Section 1: Technical Architecture of the "Hacked" Media Pipeline

The core strategy of Path 4 is to offload resource-heavy workloads (video transcoding, live video caching, and content delivery) to consumer platforms. By doing so, the platform avoids linear cloud pricing while bypassing the need to manage complex physical hardware.

![[7th.png]]

### Ingestion and Transcoding Core (YouTube Live Hack)

In Path 4, the platform uses **YouTube Live** as its main media processing and distribution engine. Broadcasters at venues in Al Khobar encode their feeds using free software like OBS Studio or vMix and push them via RTMP/RTMPS directly to YouTube's ingest endpoints.

Once received, YouTube's infrastructure automatically decodes the stream and transcodes it into a full adaptive bitrate (ABR) ladder (1080p, 720p, 480p, 360p). This eliminates the need for expensive cloud transcoding services like AWS IVS (saving $2.00/hour per active channel) or local GPU-transcoding hardware.

### Edge Distribution and Playback Hack

To keep the platform exclusive and prevent users from leaving the app, streams are configured as **Unlisted** via the YouTube Live Streaming API. Unlisted streams are hidden from public YouTube searches, channel pages, and recommendation feeds.

Inside our Flutter mobile application, we embed these streams using the open-source **`youtube_player_flutter`** plugin. This package runs a lightweight, customized `webview_flutter` under the hood to play the stream inline. This allows us to hide standard YouTube player elements, display custom branding, and handle variable connections natively on mobile networks.

## Section 2: Storage Bottleneck Mitigation (Free VOD Archiving)

Under Path 1 and Path 2, saving and archiving stream logs represents a major cost and storage bottleneck.

- **The Cloud Path:** AWS IVS recording to S3 costs $0.023 per GB/month plus CloudFront egress fees ($0.085 per GB) to play back VOD files.
- **The Self-Hosted Path:** Bare-metal servers require large physical NVMe drives configured in RAID arrays, which are capped by hardware physical limits.

### The Lifetime Storage Hack

Path 4 completely resolves the storage bottleneck. The moment a YouTube Live broadcast ends, YouTube's system automatically packages the recorded stream and archives it as a **standard unlisted VOD video** on our channel.

This provides **unlimited, free, lifetime storage** for our video logs. To surface these videos inside our app, we build a simple syncing mechanism:

![[8th.png]]

Using this architecture, the platform can store thousands of hours of historical stream logs without paying a single Riyal in storage or VOD egress fees.

## Section 3: The "Hacked" Software Stack (PocketBase + Soketi)

To replace expensive cloud identity platforms, databases, and WebSocket services, Path 4 deploys a lightweight, open-source stack that can run on a single low-cost virtual private server (VPS).

![[9th.png]]

### PocketBase: The All-in-One Backend-as-a-Service (BaaS)

Instead of using Cognito, API Gateway, Lambda, DynamoDB, and S3, Path 4 deploys **PocketBase**. Written in Go, PocketBase is a single-binary backend that bundles:

1. **Embedded SQLite Database:** Features real-time subscriptions, performing schema reads and writes with minimal CPU usage.
2. **User Authentication:** Handles secure sign-ins, JWT generations, and role-based access controls.
3. **Local File Storage:** Stores profile pictures, lecture attachments, and documents directly on the local server.
4. **Real-time Subscriptions (SSE):** Sends instant updates to connected clients using Server-Sent Events.

**Performance Profile:** Benchmarks show that PocketBase can easily serve **10,000+ concurrent real-time connections** on a cheap virtual machine with just 2 vCPUs and 4GB of RAM (costing less than SAR 25/month).

### Soketi: The High-Speed Pusher Alternative

If the platform's custom features—such as clapping, raising hands, and sending real-time emojis—scale beyond PocketBase's default real-time limits, we deploy **Soketi**.

Soketi is an open-source, Pusher-compatible WebSocket server built on `uWebSockets.js` (a C application ported to Node.js). Soketi is extremely fast, performing at **10x the speed of Socket.IO** and **8.5x the speed of Fastify**. It runs easily in less than 1 GB of RAM, allowing us to drop Pusher SDK libraries directly into our Flutter client and route all high-frequency chat and gesture traffic through our local VPS for free.

## Section 4: Local ISP Infrastructure and Physical Deployment Options

Because Path 4 offloads all video transcoding, edge delivery, and VOD hosting to YouTube's infrastructure, the bandwidth requirements at our local Al Khobar venues are exceptionally light.

### Local Ingest Bandwidth Requirements

The local venue connection is only used to upload a single live video feed directly to YouTube. Since YouTube handles the creation of the multi-bitrate ABR player ladder, we only need to upload our primary 1080p stream.

To calculate our required local upload speed:

$$\text{Required Local Upload Bandwidth} = \text{Target Video Bitrate} \times 1.5$$

Using a target video bitrate of 4.5 Mbps for a crisp 1080p stream, and applying a $1.5\times$ safety factor for network variations, the venue only requires:

$$4.5\text{ Mbps} \times 1.5 = 6.75\text{ Mbps of upload speed.}$$

This means we can run our broadcasts on a standard, low-cost commercial connection like the **stc Fiber Link 100** (offering 100 Mbps download and **20 Mbps upload** for **SAR 344/month**). This saves thousands of Riyals by avoiding expensive Dedicated Internet Access (DIA) lines.

### Local Saudi Hosting Strategy

To comply with local personal data regulations while minimizing server hosting costs, we run our PocketBase and Soketi binaries on a lightweight cloud server hosted inside Saudi Arabia.

We use **SCCC (Saudi Cloud Computing Company / Alibaba Cloud)** in their Riyadh region. SCCC offers **SAR 1,000 in free startup credits** for individual developers and up to **SAR 5,000 for enterprise accounts**. By utilizing these signup credits, we can host our entire backend database and WebSocket servers for free during our pilot phase.

## Section 5: Regulatory Compliance and Local Restrictions

Because Path 4 relies on public consumer infrastructure like YouTube, keeping the platform compliant with Saudi Arabia's strict media and religious regulations requires careful technical constraints.

### Ministry of Islamic Affairs Mosque Rules

The Ministry of Islamic Affairs, Dawah and Guidance strictly prohibits broadcasting, recording, or live streaming congregational prayers (Salah) and the call to prayer (Adhan) inside mosques across all media formats.

Under Path 4, streaming openly on YouTube poses a high risk if the stream accidentally goes public or is indexed by algorithms. We implement the following "hacks" to guarantee compliance:

1. **Unlisted API Enforcement:** When scheduling streams, our PocketBase backend calls the YouTube Data API to force the `privacyStatus` property to `unlisted`.
2. **Direct API Kill Switch:** We build a physical "kill switch" button in our admin panel. If an operator accidentally captures a prayer service, pressing the button executes a fast API transition:

Bash
```
   curl -X POST  "https://www.googleapis.com/youtube/v3/liveBroadcasts/transitin?id=VIDEO_ID&broadcastStatus=complete"
```

This immediately cuts the live stream, pulls the video feed down, and locks the playback file.

### GAMR Audiovisual Licensing

The platform must obtain an **Audiovisual Media License** from the **General Authority of Media Regulation (GAMR)**. Even though we are embedding YouTube videos, our platform operates as a standalone streaming application inside Saudi Arabia, making us legally liable for the distributed content.

The annual license starting cost ranges between **SAR 10,000 and SAR 25,000**. To operate safely and legally, this fee must be factored into our legal budget.

### PDPL Compliance and Data Residency

Under the **Personal Data Protection Law (PDPL)**, user credentials, real-time chat messages, and user interactions are classified as personal data and must remain stored within Saudi borders.

- **The Hack:** While the video streams are processed on YouTube's global CDNs, **all personal data (user profiles, auth records, chat logs) is stored locally inside our PocketBase SQLite database**. By deploying our PocketBase server inside SCCC's Riyadh region (`me-central-2`), we keep all regulated user data strictly inside Saudi Arabia, achieving full PDPL compliance.

## Section 6: Financial Complexity and Cost Projections

Path 4 is designed to minimize financial barriers, requiring no expensive server purchases (CAPEX) and keeping monthly operating costs flat regardless of our viewer numbers.

Our financial models assume a standard 1080p stream bitrate of 4.5 Mbps. Because YouTube handles all video processing, CDN edge delivery, and VOD storage for free, our cloud billing is completely decoupled from our audience size.

### Scenario A: Initial Sandbox Phase (Al Khobar Pilot)

- **Operations:** 16 streams per month, 100 concurrent viewers (CCU).
- **Cloud Transcoding & Egress Fees:** SAR 0 (YouTube Free Tier).

#### Upfront Capital Expenditure (CAPEX)

- Physical hardware purchases: **SAR 0** (Using existing venue laptops and PTZ cameras).

#### Ongoing Monthly Operational Expenditure (OPEX)

|**Service / Infrastructure Item**|**Quantitative Metrics**|**Unit Rate (SAR)**|**Total Cost (SAR)**|
|---|---|---|---|
|**stc Fiber Link 100**|100 Mbps download / 20 Mbps upload business fiber|344 / month|344.00|
|**SCCC Cloud VPS**|2 vCPU, 4GB RAM Cloud Instance (PocketBase Backend)|35.00 / month|0.00 _(Covered by SAR 5,000 Free Credits)_|
|**YouTube Data API**|Metadata lookup queries|Free Tier|0.00|
|**PocketBase DB & Auth**|Real-time user database and security platform|Open-Source|0.00|
|**Soketi WebSocket Engine**|High-throughput gesture and interactive service|Open-Source|0.00|
|**Total Monthly OPEX**|**Al Khobar Pilot Phase**|**-**|**SAR 344.00**|

### Scenario B: Scaled Regional Expansion

- **Operations:** 100 streams per month, 1,500 concurrent viewers (CCU) across the Eastern Province.
- **Cloud Transcoding & Egress Fees:** **SAR 0** (YouTube scales to handle millions of viewers automatically).

#### Upfront Capital Expenditure (CAPEX)

- Venue expansion hardware: **SAR 0** (Laptops and software encoding managed on-site).

#### Ongoing Monthly Operational Expenditure (OPEX)

|**Service / Infrastructure Item**|**Quantitative Metrics**|**Unit Rate (SAR)**|**Total Cost (SAR)**|
|---|---|---|---|
|**3x stc Fiber Link 100**|Active upload connections across 3 Al Khobar venues|344 / month per venue|1,032.00|
|**Scaled SCCC Cloud Nodes**|2x Load-balanced Cloud Instances (PocketBase + Soketi Clustering)|90.00 / month|90.00 _(After free credits expire)_|
|**PocketBase DB & Auth**|Distributed real-time database|Open-Source|0.00|
|**Soketi WebSocket Engine**|Clustered real-time chat and gesture platform|Open-Source|0.00|
|**Total Monthly OPEX**|**Regional Expansion Phase**|**-**|**SAR 1,122.00**|

### Financial Leverage Comparison

The financial efficiency of Path 4 is highly visible when compared against the cloud-native model (Path 1) as the platform scales:

- **At 100 Viewers:** Path 1 costs **SAR 1,424.52/month**. Path 4 slashes this to **SAR 344.00/month**.
- **At 1,500 Viewers:** Under Path 1, our monthly AWS bill balloons to **SAR 66,594.38** due to high egress fees. Under Path 4, our monthly bill remains flat at **SAR 1,122.00**. YouTube handles the massive viewer bandwidth for free, saving the platform **over SAR 65,000 every single month**.

## Section 7: Integration and Migration of Legacy Logs

To import our existing pre-recorded stream logs into the platform without paying for storage or transcoding, we use our unlisted YouTube video strategy:

![[10th.png]]

1. **Local Batch Uploading:** We write a simple Python script using the Google API Client Library to parse our local video folders and upload files directly to our YouTube channel:
Python
```
    request = youtube.videos().insert(
        part="snippet,status",
        body={
            "snippet": {"title": "Legacy Lecture 01", "description": "Archived log"},
            "status": {"privacyStatus": "unlisted"}
        },
        media_body=MediaFileUpload("legacy_video.mp4")
    )
```
1. **Automatic Transcoding:** YouTube receives the files, transcodes them into standard web formats for free, and generates a unique Video ID.
2. **Database Indexing:** Our script captures the returned Video ID and writes a new metadata row (Title, Speaker, Date, and Video ID) directly to our local PocketBase SQLite database.
3. **App Playback:** When a user opens the video library inside the Flutter app, the player fetches the Video ID from PocketBase and plays the video inline via the embedded player.

## Section 8: 12-Month Implementation Plan and Road Map

Because Path 4 avoids hardware setups and complex cloud architectures, the rollout timeline is accelerated.

|**Roadmap Phase**|**Target Duration**|**Operational Objectives**|**Technical Milestones**|**Regulatory Deliverables**|
|---|---|---|---|---|
|**Phase 1: Environment Setup**|Month 1|Set up Google Developer Console; launch local PocketBase server.|Configure unlisted stream profiles; test PocketBase database.|Begin preparing GAMR license application documentation.|
|**Phase 2: App Development**|Months 2–3|Build the Flutter mobile app; integrate inline video and chat overlays.|Integrate `youtube_player_flutter`; connect Soketi and PocketBase real-time client SDKs.|Submit official application to GAMR for the Audiovisual Media License.|
|**Phase 3: Beta Launch**|Months 4–6|Run a private beta with 100 users in Al Khobar; stream 1 to 5 events weekly.|Verify unlisted streaming keys; test automated stream-to-VOD archiving.|Secure GAMR license ; test compliance overrides for mosque talks.|
|**Phase 4: Platform Scale-Up**|Months 7–9|Launch public app across the Eastern Province; scale to multiple concurrent streams.|Cluster PocketBase and Soketi instances on local SCCC servers.|Monitor CST user thresholds (Apply for registration upon reaching 35,000 subscribers).|
|**Phase 5: Optimization**|Months 10–12|Audit user feedback, optimize playback buffers, and run load testing.|Run load tests using `srs-bench` Docker containers; optimize database query paths.|Perform physical and digital PDPL compliance audits.|

## Strategic Conclusions

Path 4 is the **most viable bootstrapping strategy** for launching our educational streaming platform. By utilizing YouTube for all video transcoding, edge delivery, and VOD storage, we completely eliminate the major technical and financial bottlenecks of the project, allowing us to stream to thousands of concurrent users for less than **SAR 1,200/month**.

Additionally, hosting our PocketBase backend on local Saudi cloud servers like SCCC ensures that our user data remains strictly inside the country, achieving full **PDPL compliance** while keeping our hosting costs covered by free startup credits.

The primary risk of Path 4 is its dependency on YouTube's Terms of Service and API policies. If Google changes its mobile embedding rules or restricts unlisted video delivery, our media pipeline could be affected.

Therefore, our strategic recommendation is to **launch the pilot phase on Path 4 to validate the app's market fit**. However, we should build our Flutter application using a modular player interface. This ensures that if we grow and decide to transition to a self-hosted pipeline (Path 2) or a hybrid model (Path 3) in the future, we can easily swap our YouTube player for our own streaming servers without rewriting our application code.