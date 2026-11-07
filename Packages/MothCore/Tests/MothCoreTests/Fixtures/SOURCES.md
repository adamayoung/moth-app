# Fixture Sources

`aws-signing-test-suite/` holds unchanged copies of files from the `v4` folder of
AWS's [SigV4 test suite](https://github.com/awslabs/aws-c-auth/tree/bdb7cef99d8bd1ad3c189b1400140a7787e47105/tests/aws-signing-test-suite/v4),
at commit `bdb7cef`, `Copyright Amazon.com, Inc. or its affiliates`. Each case
keeps `context.json`, `request.txt` and the `header-` files for its canonical
request, string to sign and signature, and leaves out the query-signing files.
[LICENSE](LICENSE) holds the repository's Apache-2.0 text. Moth's own MIT licence
doesn't apply to these files.
