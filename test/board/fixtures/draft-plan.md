# Add webhook support

> Allow external services to trigger plot phase transitions via webhooks.

## Status

- **Phase:** Draft
- **Type:** feature

## Changelog

- Add webhook endpoint for phase transitions

## Motivation

Some CI/CD pipelines need to trigger plot phase changes automatically.

## Design

### Approach

Add a new endpoint that accepts signed webhook payloads.

## Branches

- `feature/webhook-support` — implement the webhook handler

## Notes

Initial draft.
