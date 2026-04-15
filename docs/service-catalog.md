# Service Catalog

The service catalog lives in:

- `catalog/services.yaml`

It defines deployment metadata shared across environments, including:

- canonical service name
- source repository
- image repository
- deployment group
- rollout order
- default deployment strategy

## Current Services

The initial catalog covers:

- control-plane services from `raksha-platform`
- runtime services from `raksha-ingestion-gateway`
- runtime services from `raksha-engine`
- runtime services from `raksha-notifier-gateway`

## Purpose

The catalog gives deployment automation one stable description of:

- what services exist
- where their artifacts come from
- how they should be sequenced
