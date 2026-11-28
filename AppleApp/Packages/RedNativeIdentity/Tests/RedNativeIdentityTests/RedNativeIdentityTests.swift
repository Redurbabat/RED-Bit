import XCTest
import Foundation
import CryptoKit
@testable import RedNativeIdentity

final class RedNativeIdentityTests: XCTestCase {
    func testProofAndPayload() throws {
        let a = RedNativeClient.makeProof(), b = RedNativeClient.makeProof()
        XCTAssertEqual(a.verifier.count, 43)
        XCTAssertEqual(a.challenge.count, 43)
        XCTAssertNotEqual(a.verifier, b.verifier)
        let expected = Data(SHA256.hash(data: Data(a.verifier.utf8))).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        XCTAssertEqual(a.challenge, expected)
        let payload = try RedNativeClient.pairingRequest(app: "red-bit", challenge: a.challenge)
        XCTAssertFalse(payload.contains(a.verifier))
        let decoded = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String:Any])
        XCTAssertEqual(decoded["app"] as? String, "red-bit")
        XCTAssertEqual(decoded["challenge"] as? String, a.challenge)
        XCTAssertThrowsError(try RedNativeClient.pairingRequest(app: "unknown", challenge: a.challenge))
    }
    func testQRCode() throws {
        let proof = RedNativeClient.makeProof()
        let a = try RedPairQRCode.image(app: "red-bit", challenge: proof.challenge, scale: 4)
        XCTAssertGreaterThan(a.width, 100)
        XCTAssertEqual(a.width, a.height)
        XCTAssertEqual(a.width % 4, 0)
        XCTAssertThrowsError(try RedPairQRCode.image(app: "red-bit", challenge: proof.challenge, scale: 0))
    }
    func testRedBitPermissionStrictContractAndExpiry() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let expiry = now.addingTimeInterval(1800)
        let sessionExpiry = now.addingTimeInterval(7200)
        let good: [String: Any] = [
            "version": 1, "app": "red-bit", "scope": "music:status:read",
            "expiresAt": Int64(expiry.timeIntervalSince1970 * 1000), "remoteAvailable": false
        ]
        func decode(_ value: [String: Any], session: Date = sessionExpiry) throws -> RedBitServerPermission {
            try RedBitServerPermission.validated(JSONSerialization.data(withJSONObject: value),
                                                 now: now, sessionExpiry: session)
        }
        let permission = try decode(good)
        XCTAssertEqual(permission.expiryDate, expiry)
        XCTAssertFalse(permission.remoteAvailable)
        let badValues: [(String, Any)] = [
            ("version", 2), ("app", "red-fit"), ("scope", "music:transport"),
            ("remoteAvailable", true), ("remoteAvailable", 0),
            ("expiresAt", Int64(now.timeIntervalSince1970 * 1000)),
            ("expiresAt", Int64(now.addingTimeInterval(7200).timeIntervalSince1970 * 1000)),
            ("expiresAt", "1800001800000"), ("token", "private")
        ]
        for (key, value) in badValues {
            var invalid = good
            invalid[key] = value
            XCTAssertThrowsError(try decode(invalid), key)
        }
        for key in good.keys {
            var missing = good
            missing.removeValue(forKey: key)
            XCTAssertThrowsError(try decode(missing), key)
        }
        XCTAssertThrowsError(try decode(good, session: now.addingTimeInterval(100)))
        XCTAssertThrowsError(try RedBitServerPermission.validated(Data(repeating: 0, count: 2049),
                                                                  now: now, sessionExpiry: sessionExpiry))
    }

    func testPermissionRejectsOtherAppBeforeCredentials() async throws {
        struct NoAccessStore: RedNativeCredentialStore {
            func load(scope: String) throws -> Data? { XCTFail("Unexpected credential read"); return nil }
            func save(_ value: Data, scope: String) throws { XCTFail("Unexpected credential write") }
            func clear(scope: String) throws { XCTFail("Unexpected credential removal") }
        }
        let client = try RedNativeClient(origin: "https://home.example.test", app: "red-fit", store: NoAccessStore())
        do {
            _ = try await client.redBitPermission()
            XCTFail("Unexpected permission")
        } catch {
            XCTAssertEqual(error as? RedNativeError, .invalidApp)
        }
    }

    func testReadJobClaimStrictContract() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let expiry = now.addingTimeInterval(90)
        let valid: [String: Any] = ["id": String(repeating: "a", count: 32),
            "tool": "redbit_read_status", "expiresAt": Int64((now.timeIntervalSince1970 + 30) * 1000)]
        func parse(_ job: Any) throws -> RedBitReadJob? {
            try RedBitReadJob.parseClaim(JSONSerialization.data(withJSONObject: ["version": 1, "job": job]),
                                          now: now, sessionExpiry: expiry)
        }
        XCTAssertNil(try parse(NSNull()))
        XCTAssertEqual(try parse(valid)?.id, valid["id"] as? String)
        for (key, value) in [("tool", "redbit_play" as Any), ("id", "../bad" as Any),
            ("expiresAt", Int64(now.timeIntervalSince1970 * 1000) as Any),
            ("expiresAt", Int64((now.timeIntervalSince1970 + 46) * 1000) as Any),
            ("arguments", ["percent": 100] as Any)] {
            var bad = valid; bad[key] = value
            XCTAssertThrowsError(try parse(bad), key)
        }
        XCTAssertThrowsError(try RedBitReadJob.parseClaim(Data("{\"version\":1}".utf8), now: now, sessionExpiry: expiry))
    }

    func testReadJobCompletionRejectsPrivateDataAndInvalidTypes() throws {
        let id = String(repeating: "b", count: 32)
        let good: [String: Any] = ["version": 1, "state": "paused", "hasTrack": true,
            "canNext": false, "canPrevious": false, "controlsLocked": false, "hasPlaybackError": false,
            "positionSeconds": 2, "durationSeconds": 30]
        func encode(_ object: [String: Any]) throws -> Data {
            let data = try JSONSerialization.data(withJSONObject: object)
            return try RedBitReadJob.completionBody(id: id, status: String(decoding: data, as: UTF8.self))
        }
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: encode(good)) as? [String: Any])
        XCTAssertEqual(Set(body.keys), Set(["id", "status"]))
        XCTAssertEqual(body["id"] as? String, id)
        for (key, value) in [("title", "private" as Any), ("token", "private" as Any),
            ("state", "private" as Any), ("hasTrack", 1 as Any), ("durationSeconds", -1 as Any),
            ("positionSeconds", NSNull() as Any), ("positionSeconds", true as Any)] {
            var bad = good; bad[key] = value
            XCTAssertThrowsError(try encode(bad), key)
        }
        XCTAssertNoThrow(try RedBitReadJob.validateReceipt(Data("{\"ok\":true}".utf8)))
        for raw in ["{\"ok\":false}", "{\"ok\":1}", "{\"ok\":true,\"token\":\"private\"}"] {
            XCTAssertThrowsError(try RedBitReadJob.validateReceipt(Data(raw.utf8)))
        }
    }

    func testScopes() throws {
        let a = try RedNativeClient.credentialScope(origin: "https://home.example.test", app: "red-bit")
        XCTAssertEqual(a.count, 64)
        XCTAssertNotEqual(a, try RedNativeClient.credentialScope(origin: "https://other.example.test", app: "red-bit"))
        XCTAssertNotEqual(a, try RedNativeClient.credentialScope(origin: "https://home.example.test", app: "red-yt"))
        for bad in ["http://home.example.test","https://home.example.test/path","https://user@home.example.test","https://home.example.test?x=y","https://home.example.test:443"] {
            XCTAssertThrowsError(try RedNativeClient.credentialScope(origin: bad, app: "red-bit"))
        }
    }
}
