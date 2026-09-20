// Private broadcasts require server-enforced entitlements before release.
const kPrivateStreamingEnabled = false;

// Venue seating and in-person RSVP have no backend: nothing records an
// attendance and the seat numbers were produced on the device. The entry
// points stay hidden until a real attendance table exists (05 D-03).
const kVenueRsvpEnabled = false;
