//  CurlImportRealCommandTests.swift
//  MothImport
//
//  Copyright © 2026 Adam Young.

import MothCore
import MothImport
import Testing

@Suite("Commands copied from each API's documentation")
struct CurlImportRealCommandTests {

    private static let formType = "application/x-www-form-urlencoded"

    /// https://docs.github.com/en/rest/issues/issues#create-an-issue
    private static let gitHub = #"""
    curl -L \
      -X POST \
      https://api.github.com/repos/OWNER/REPO/issues \
      -d '{
      "title": "Found a bug",
      "body": "I'\''m having a problem with this.",
      "assignees": [
        "octocat"
      ],
      "milestone": 1,
      "labels": [
        "bug"
      ]
    }'
    """#

    /// https://docs.stripe.com/api/customers/create
    private static let stripe = #"""
    curl https://api.stripe.com/v1/customers \
      -u "<<YOUR_SECRET_KEY>>" \
      -H "Stripe-Version: 2026-10-28.endive" \
      -d "name=Jenny Rosen" \
      --data-urlencode "email=jennyrosen@example.com"
    """#

    /// https://www.twilio.com/docs/messaging/api/message-resource
    private static let twilio = #"""
    curl -X POST "https://api.twilio.com/2010-04-01/Accounts/$TWILIO_ACCOUNT_SID/Messages.json" \
    --data-urlencode "From=+15557122661" \
    --data-urlencode "Body=Hi there" \
    --data-urlencode "To=+15558675310" \
    -u $TWILIO_API_KEY:$TWILIO_API_SECRET
    """#

    /// https://platform.claude.com/docs/en/api/messages-examples
    private static let anthropic = #"""
    #!/bin/sh
    curl https://api.anthropic.com/v1/messages \
      -H "x-api-key: $ANTHROPIC_API_KEY" \
      -H "anthropic-version: 2026-10-21" \
      -H "content-type: application/json" \
      -d '{
        "model": "claude-opus-5-5",
        "max_tokens": 1024,
        "messages": [
          {"role": "user", "content": "Hello, Claude"}
        ]
      }'
    """#

    /// https://www.twilio.com/docs/sendgrid/api-reference/mail-send/mail-send, with the body cut to its first field.
    private static let sendGrid = #"""
    curl -X POST "https://api.sendgrid.com/v3/mail/send" \
    --header "Content-Type: application/json" \
    --data '{"subject": "Your Example Order Confirmation"}'
    """#

    @Test("GitHub: -L, -X, a URL between flags, and a quote escaped inside single quotes")
    func gitHub() async throws {
        let request = try await CurlImportTesting.request(Self.gitHub)

        #expect(request.name == "POST /repos/OWNER/REPO/issues")
        #expect(request.urlTemplate == "https://api.github.com/repos/OWNER/REPO/issues")
        #expect(request.settings.followsRedirects)
        guard case .raw(let content, let contentType) = request.body else {
            Issue.record("Expected a raw body")
            return
        }
        #expect(content.contains(#""body": "I'm having a problem with this.","#))
        #expect(content.hasSuffix("}"))
        #expect(contentType == Self.formType)
    }

    @Test("Stripe: -u with a key alone, a header, and -d beside --data-urlencode")
    func stripe() async throws {
        let store = RecordingSecretStore()
        let result = try await CurlImportTesting.importing(Self.stripe, secretStore: store)
        let request = result.request

        #expect(request.name == "POST /v1/customers")
        #expect(request.headers.pairs == [Pair("Stripe-Version", "2026-10-28.endive")])
        #expect(result.ignored.isEmpty)
        guard case .urlEncoded(let rows) = request.body, case .basic(let auth) = request.auth else {
            Issue.record("Expected form rows and Basic Auth")
            return
        }
        #expect(rows.pairs == [Pair("name", "Jenny Rosen"), Pair("email", "jennyrosen@example.com")])
        #expect(auth.username == "<<YOUR_SECRET_KEY>>")
        #expect(await store.values[auth.password.identifier] == "")
    }

    @Test("Twilio: a + kept by --data-urlencode, and shell variables left as written")
    func twilio() async throws {
        let store = RecordingSecretStore()
        let request = try await CurlImportTesting.importing(Self.twilio, secretStore: store).request

        #expect(request.urlTemplate == "https://api.twilio.com/2010-04-01/Accounts/$TWILIO_ACCOUNT_SID/Messages.json")
        guard case .urlEncoded(let rows) = request.body, case .basic(let auth) = request.auth else {
            Issue.record("Expected form rows and Basic Auth")
            return
        }
        #expect(rows.pairs == [
            Pair("From", "+15557122661"), Pair("Body", "Hi there"), Pair("To", "+15558675310")
        ])
        #expect(auth.username == "$TWILIO_API_KEY")
        #expect(await store.values[auth.password.identifier] == "$TWILIO_API_SECRET")
    }

    @Test("Anthropic: a #! line before the command, and a JSON body under a lowercase header")
    func anthropic() async throws {
        let request = try await CurlImportTesting.request(Self.anthropic)

        #expect(request.name == "POST /v1/messages")
        #expect(request.headers.map(\.key) == ["x-api-key", "anthropic-version", "content-type"])
        guard case .raw(let content, let contentType) = request.body else {
            Issue.record("Expected a raw body")
            return
        }
        #expect(content.contains(#""max_tokens": 1024"#))
        #expect(contentType == "application/json")
    }

    @Test("SendGrid: the long forms --header and --data")
    func sendGrid() async throws {
        let request = try await CurlImportTesting.request(Self.sendGrid)

        #expect(request.name == "POST /v3/mail/send")
        #expect(request.headers.pairs == [Pair("Content-Type", "application/json")])
        #expect(request.body == .raw(
            content: #"{"subject": "Your Example Order Confirmation"}"#,
            contentType: "application/json"
        ))
    }

}
