# NOMAD-gui Architecture on AWS

## 1. Why this document exists

NOMAD-gui is a first-class part of user experience and must be planned explicitly.

This document defines low-cost MVP handling first, with a safe path to higher-scale frontend delivery later.

## 2. GUI deployment models

## Model A: Bundled GUI via app/proxy (MVP default)

Flow:

1. Browser -> Route 53 -> ALB
2. ALB -> nginx/proxy service
3. proxy -> app service serves GUI routes/assets and API responses

Pros:

- Lowest complexity
- Single deployment/rollback unit
- No frontend/backend drift risk when released together

Cons:

- App pods also serve static assets
- Less optimal for global edge caching

Use when:

- Starting MVP
- Team wants simple operations and fast iteration

## Model B: Split GUI static hosting (S3 + CloudFront)

Flow:

1. Browser requests static GUI assets from CloudFront
2. CloudFront origin is versioned S3 objects
3. GUI API calls go to ALB -> proxy -> app

Pros:

- Lower latency for static assets
- Reduces app pod load
- Better global delivery characteristics

Cons:

- More release coordination
- Requires cache/version strategy to avoid stale UI issues

Use when:

- GUI traffic is high and mostly static-heavy
- Need independent frontend release cadence

## 3. Recommended sequence for your project

1. MVP: Model A (bundled GUI)
2. Observe real traffic and app CPU/memory profile
3. If needed, migrate to Model B in a controlled phase

## 4. GUI-specific AWS services compatibility

| Concern | Compatible AWS service(s) | MVP choice |
|---|---|---|
| Public endpoint | ALB + Route 53 + ACM | Yes |
| Edge caching | CloudFront | Later phase |
| Static asset origin | S3 | Later phase |
| Logs/metrics | CloudWatch, ALB access logs, CloudFront metrics | CloudWatch + ALB first |
| Security headers and WAF | AWS WAF, ALB/CloudFront policies | Add after MVP baseline |

## 5. Cost and performance guidance for GUI

- Start bundled: cheapest operationally and easiest to support.
- Move to CDN only if measurable benefit exists:
  - high static asset traffic
  - app pod pressure from static serving
  - geographic latency concerns

Rule of thumb:

- If app autoscaling is mostly triggered by GUI static traffic rather than API/business traffic, CDN split is likely worth it.

## 6. GUI test checklist (must-pass)

1. GUI shell loads under ALB endpoint.
2. Static assets resolve correctly with no mixed-version issues.
3. Auth/login and token handling works across refreshes.
4. Core screens work: search, upload, entry details.
5. Error handling works for API 4xx/5xx responses.
6. Performance baseline captured:
  - first contentful paint
  - largest contentful paint
  - key API latency

## 7. GUI release safety

- Use immutable asset filenames/content hashing.
- Keep quick rollback path to previous app image (bundled mode) or previous asset manifest (CDN mode).
- Gate releases with smoke tests before full rollout.
