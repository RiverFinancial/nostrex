
# Nostrex

Nostrex is a Nostr relay written in Elixir. It is designed to be highly scalable and very operator-friendly to empower the rapid adoption of the Nostr protocol. Nostrex has a number of qualities and features that make it a compelling relay implementation.

### Concurrency

The Erlang OTP gives us the primitives necessary to build high-throughput, concurrent high-uptime message routing software. The OTP has been hardened and optimized over decades and a single beefy server should be able to handle millions of concurrent connections.

### Database optimization

One of the major bottlenecks of scaling a relay are the database operations. Nostrex has already implemented a number of optimizations at the DB level, including partitioning by Event `created_at` timestamps to keep table sizes in check.

### Fast Filtering

Nostrex takes full advantage of the Erlang OTP's ETS in-memory datastore as the global state for a fast-filtering algorithm that efficiently matches events to filters instead of brute-forcing and checking each new event against every registered filter. There is still a lot of room to improve this algo.

### Solid Foundation

The Erlang OTP allowed Whatsapp to scale to billions of users with a small team of engineers. With the right optimizations I feel confident that a single beefy Nostr instance will be able to power millions of concurrent connections.

### Rate limiting

IP-based rate limiting for sockets, filters, and events is implemented and configurable.

### Load testing

Load testing tooling is located in the `/load_testing` repo.


## TODOs for being production ready
- [ ] Validate event signatures (waiting on Bitcoinex lib updates)
- [ ] Remove unused boilerplate code
- [ ] Add prometheus monitoring
- [ ] Create better filter tests to uncover any remaining edge cases

## Supported NIPS
- [X] NIP 01 Basic protocol flow description
- [X] NIP 02 Contact List and Petnames
- [X] NIP 04 Encrypted Direct Message
- [ ] NIP 09 Event Deletion
- [X] NIP 11 Relay Information Document
- [ ] NIP 12 Generic Tag Queries
- [ ] NIP 15 End of Stored Events Notice
- [ ] NIP 20 Command Results
- [ ] NIP 40 Expiration Timestamp
