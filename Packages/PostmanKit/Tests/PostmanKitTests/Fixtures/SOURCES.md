# Fixture Sources

Every `.json` file here is an unchanged copy of a file from one of Postman's
Apache-2.0 repositories, or from the AWS sample in the last section, which has a
licence of its own. [LICENSE](LICENSE) holds the Apache-2.0 text, which is the
same in each Postman repository apart from its copyright line. Moth's own MIT
licence doesn't apply to these files.

An **app export** carries the Postman app's own marks: `_exporter_id`, or
`_postman_exported_using`. **Postman-authored** means Postman wrote the file for
its own tests or examples, by hand or with a tool, so it shows what Postman's
tools accept rather than what the app writes.

## newman

`Copyright 2016 Postdot Technologies, Inc`, commit
[`8fbb2eb`](https://github.com/postmanlabs/newman/tree/8fbb2eb43860193344dcccec3f67ec62c77d80f9).

| Fixture | Upstream path | Kind |
| --- | --- | --- |
| `newman/slashed-variable-names.postman_environment.json` | `test/integration/slashed-variable-names/slashed-variable-names.postman_environment.json` | App export, Postman/4.7.0 |
| `newman/bom-in-environment-file.postman_environment.json` | `test/integration/bom-and-encoding/bom-in-environment-file.postman_environment.json` | App export, Postman/4.7.0, with a byte order mark added |
| `newman/env.json` | `test/fixtures/overrides/env.json` | App export, Postman/6.6.1 |
| `newman/disabled-and-duplicates.postman_environment.json` | `test/integration/disabled-and-duplicate-variables/disabled-and-duplicates.postman_environment.json` | Postman-authored |

## openapi-to-postman

`Copyright 2018 Postman, Inc`, commit
[`e2fa8b1`](https://github.com/postmanlabs/openapi-to-postman/tree/e2fa8b1b82bcfd1c6554026d975707a32710db52).

| Fixture | Upstream path | Kind |
| --- | --- | --- |
| `openapi-to-postman/collection.json` | `test/data/disabled_query_param_test_data/collection.json` | App export |
| `openapi-to-postman/internalRefsCollection.json` | `test/data/validationData/internalRefsCollection.json` | Postman-authored |

## postman-cli-action

`Copyright 2025 Postman, Inc.`, commit
[`13241b5`](https://github.com/postmanlabs/postman-cli-action/tree/13241b5d61587b07717d83c982b7ef88fea509a4).

| Fixture | Upstream path | Kind |
| --- | --- | --- |
| `postman-cli-action/postman-echo-environment.json` | `tests/postman-echo-environment.json` | Postman-authored |

## postman-code-generators

`Copyright 2017 Postdot Technologies Pvt. Ltd.`, commit
[`7298195`](https://github.com/postmanlabs/postman-code-generators/tree/729819591582d94f0fec89e150335d54d6ce7a32).
Every file is Postman-authored, from `test/codegen/newman/fixtures/`.

| Fixture | Upstream file |
| --- | --- |
| `postman-code-generators/basicCollection.json` | `basicCollection.json` |
| `postman-code-generators/formdataCollection.json` | `formdataCollection.json` |
| `postman-code-generators/formdataFileCollection.json` | `formdataFileCollection.json` |
| `postman-code-generators/unsupportedMethods.json` | `unsupportedMethods.json` |

## postman-collection-transformer

`Copyright 2015 Postdot Technologies Pvt. Ltd.`, commit
[`d148d6a`](https://github.com/postmanlabs/postman-collection-transformer/tree/d148d6af757ff37e22e9b907e118e1b05a2952fb).
Every file is Postman-authored, from `examples/`.

| Fixture | Upstream path | Note |
| --- | --- | --- |
| `postman-collection-transformer/v2.1.0/binary-upload.json` | `examples/v2.1.0/binary-upload.json` | |
| `postman-collection-transformer/v2.1.0/nestedEntities.json` | `examples/v2.1.0/nestedEntities.json` | |
| `postman-collection-transformer/v2.1.0/helpers.json` | `examples/v2.1.0/helpers.json` | Some items use `headers`, `events` and `responses`, which v2.1 doesn't define. PostmanKit ignores those keys |
| `postman-collection-transformer/v2.1.0/proper-description-parsing.json` | `examples/v2.1.0/proper-description-parsing.json` | Sits in the v2.1.0 folder but declares the v2.0.0 schema, so `PostmanCollection` rejects it |
| `postman-collection-transformer/v1.0.0/binary-upload.json` | `examples/v1.0.0/binary-upload.json` | Collection v1, which has no `info` object |

## postman-schemas

`Copyright 2015 Postdot Technologies Pvt. Ltd.`, commit
[`c5fa20c`](https://github.com/postmanlabs/schemas/tree/c5fa20c6210207d09b06a23d700f9228c31ad703).

| Fixture | Upstream path | Kind |
| --- | --- | --- |
| `postman-schemas/apikeyAuthTest.json` | `examples/draft-04/v2.1.0/apikeyAuthTest.json` | Postman-authored. Declares the `http` form of the schema URL, so `PostmanCollection` rejects it as it is |

## aws-iam-identity-center-extensions

`Copyright (c) 2021 Amazon Web Services, Inc. or its affiliates.`, MIT, in
[`aws-iam-identity-center-extensions/LICENSE`](aws-iam-identity-center-extensions/LICENSE),
commit
[`aa597cb`](https://github.com/aws-samples/aws-iam-identity-center-extensions/tree/aa597cbc92d5506a5ac7a77f86a33cf75cc2dc3d).

| Fixture | Upstream path | Kind |
| --- | --- | --- |
| `aws-iam-identity-center-extensions/aws-sso-extensions-for-enterprise.postman_collection.json` | `docs/samples/postman-collection/aws-sso-extensions-for-enterprise.postman_collection.json` | App export with AWS Signature on every request, which leaves out `service` because it was blank |
