package utils

import (
	"github.com/sagernet/sing-box/experimental/libbox"
)

type Opts struct {
	LogDir           string
	DataDir          string
	Deviceid         string
	AppVersion       string
	LogLevel         string
	Locale           string
	TimeZone         string
	Env              string
	TelemetryConsent bool
	Platform         PlatformInterface
}

// RadianceEnvOverrides returns values that mobile and extension processes may
// not inherit from the host. In particular, Radiance needs the installed app
// version for message targeting.
//
// MYX-VPN: the host passes MYX's own app version, which must not reach the
// backend (it gates server lists on the upstream client version). The core
// keeps the version linked in at build time (CORE_VERSION in the Makefile).
func (o *Opts) RadianceEnvOverrides() map[string]string {
	return nil
}

// IsStaging reports whether Env selects the staging environment. Both
// spellings are accepted; keep every env check on this method so the
// vocabulary can't drift between call sites.
func (o *Opts) IsStaging() bool {
	return o.Env == "stage" || o.Env == "staging"
}

type PrivateServerEventListener interface {
	OpenBrowser(url string) error
	OnPrivateServerEvent(event string)
	OnError(err string)
}

// FlutterEvent represents the structure sent to Flutter.
type FlutterEvent struct {
	Type    string `json:"type"`
	Message string `json:"message"`
}

type FlutterEventEmitter interface {
	SendEvent(event *FlutterEvent)
}

// highVolumeEvents arrive too often to log their payloads, as the iOS, macOS and
// Android listeners treat them too. The snapshots come every second while sharing
// and carry the addresses of the peers relayed.
var highVolumeEvents = map[string]bool{
	"peer-connection":    true,
	"data-cap-event":     true,
	"unbounded-snapshot": true,
	"peer-snapshot":      true,
}

// IsHighVolumeEvent reports whether only an event's type should be logged.
func IsHighVolumeEvent(eventType string) bool {
	return highVolumeEvents[eventType]
}

// LogListener receives log entries streamed from the IPC client.
type LogListener interface {
	OnLogEntry(entry string)
}

type PlatformInterface interface {
	libbox.PlatformInterface
	RestartService() error
	PostServiceClose()
}

// SameInterfaceUpdateListener compares the Go listener behind gomobile proxies.
func SameInterfaceUpdateListener(a, b libbox.InterfaceUpdateListener) bool {
	return a != nil && b != nil && a == b
}
