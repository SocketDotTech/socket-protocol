# SOCKET Protocol

> The protocol is on alpha-stage and in active development.

SOCKET Protocol is the first chain-abstraction protocol, enabling developers to build chain-abstracted applications to compose users, accounts and applications across 300+ rollups and chains. Chain-Abstraction is a new computing paradigm for developers, enabling developers to leverage chains as servers/databases, enabling them to reach all users and applications spread across networks while providing a consistent monolithic experience to end users and applications.

SOCKET is a chain-abstraction protocol, not a network(chain/rollup). Using a combination of offchain agents(watchers, transmitters) and onchain contracts(switchboards) it enables application-builders to build truly chain-abstracted protocols.

Find more information at [docs](https://docs.socket.tech)

# Code Guidelines:

- always inherit at the end
- always add storage to Storage contracts
- Storage contracts should have gaps before and after
- update gaps after every change
- update version after every change
- never remove code
- inherited contracts should have gaps at the end to avoid storage collision
- write tests for migration checking slots after the change
-
