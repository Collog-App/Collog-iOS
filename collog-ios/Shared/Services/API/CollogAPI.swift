//
//  CollogAPI.swift
//  collog-ios
//
//  Created by dohyeoplim on 8/18/26.
//

import Foundation

struct CollogAPI {
    let client: CollogAPIClient

    func requestOtp(phone: String, role: String, name: String) async throws {
        try await client.sendRaw(
            APIEndpoint(
                path: "/v1/auth/otp/request",
                method: .post,
                body: OtpRequestBody(phone: phone, role: role, name: name),
                requiresAuth: false
            )
        )
    }

    func verifyOtp(phone: String, code: String) async throws -> TokenResponse {
        try await client.send(
            APIEndpoint(
                path: "/v1/auth/otp/verify",
                method: .post,
                body: OtpVerifyBody(phone: phone, code: code),
                requiresAuth: false
            )
        )
    }

    func registerDevice(token: String, voipToken: String?) async throws -> DeviceCreated {
        try await client.send(
            APIEndpoint(
                path: "/v1/devices",
                method: .post,
                body: DeviceCreateBody(platform: "IOS", token: token, voipToken: voipToken)
            )
        )
    }

    func members(familyId: String) async throws -> [FamilyMember] {
        let response: FamilyMembersResponse = try await client.send(
            APIEndpoint(path: "/v1/families/\(familyId)/members")
        )
        return response.members
    }

    func dailyQuestions(parentId: String) async throws -> [APIQuestion] {
        let response: DailyQuestionsResponse = try await client.send(
            APIEndpoint(path: "/v1/parents/\(parentId)/daily-questions")
        )
        return response.questions
    }

    func consentDocument() async throws -> ConsentDocument {
        try await client.send(APIEndpoint(path: "/v1/consents/document", requiresAuth: false))
    }

    func submitConsent(
        documentVersion: String,
        agreedItems: [String],
        decision: String = "GRANT"
    ) async throws -> ConsentRecordDTO {
        try await client.send(
            APIEndpoint(
                path: "/v1/consents",
                method: .post,
                body: ConsentSubmitBody(
                    documentVersion: documentVersion,
                    decision: decision,
                    scrolledToEnd: true,
                    agreedItems: agreedItems
                )
            )
        )
    }

    func myConsent() async throws -> ConsentRecordDTO {
        try await client.send(APIEndpoint(path: "/v1/consents/me"))
    }

    func profile(parentId: String) async throws -> ProfileDTO {
        try await client.send(APIEndpoint(path: "/v1/parents/\(parentId)/profile"))
    }

    func updateProfile(parentId: String, conditions: [String]) async throws -> ProfileDTO {
        try await client.send(
            APIEndpoint(
                path: "/v1/parents/\(parentId)/profile",
                method: .put,
                body: ProfilePutBody(conditions: conditions)
            )
        )
    }

    func createInvitation(familyId: String, name: String, relation: String) async throws -> InvitationDTO {
        try await client.send(
            APIEndpoint(
                path: "/v1/families/\(familyId)/invitations",
                method: .post,
                body: InvitationCreateBody(name: name, relation: relation)
            )
        )
    }

    func acceptInvitation(code: String) async throws {
        try await client.sendRaw(
            APIEndpoint(
                path: "/v1/invitations/accept",
                method: .post,
                body: InvitationAcceptBody(code: code)
            )
        )
    }

    func calls(parentId: String, from: String? = nil, to: String? = nil) async throws -> [CallSummaryDTO] {
        var query: [URLQueryItem] = []
        if let from { query.append(URLQueryItem(name: "from", value: from)) }
        if let to { query.append(URLQueryItem(name: "to", value: to)) }

        let response: CallsResponse = try await client.send(
            APIEndpoint(path: "/v1/parents/\(parentId)/calls", query: query)
        )
        return response.calls
    }

    func report(
        parentId: String,
        period: String = "WEEKLY",
        date: String? = nil
    ) async throws -> ReportDTO {
        var query = [URLQueryItem(name: "period", value: period)]
        if let date { query.append(URLQueryItem(name: "date", value: date)) }

        return try await client.send(
            APIEndpoint(path: "/v1/parents/\(parentId)/reports", query: query)
        )
    }

    func baselines(parentId: String) async throws -> [BaselineDTO] {
        let response: BaselinesResponse = try await client.send(
            APIEndpoint(path: "/v1/parents/\(parentId)/baseline")
        )
        return response.baselines
    }

    func acousticFeatures(callId: String) async throws -> AcousticFeaturesDTO {
        try await client.send(APIEndpoint(path: "/v1/calls/\(callId)/acoustic-features"))
    }

    func extraction(callId: String) async throws -> ExtractionDTO {
        try await client.send(APIEndpoint(path: "/v1/calls/\(callId)/extraction"))
    }

    func transcript(callId: String) async throws -> TranscriptDTO {
        try await client.send(APIEndpoint(path: "/v1/calls/\(callId)/transcript"))
    }

    func createCall(calleeId: String) async throws -> CallCreated {
        try await client.send(
            APIEndpoint(path: "/v1/calls", method: .post, body: CallCreateBody(calleeId: calleeId))
        )
    }

    func acceptCall(callId: String) async throws -> CallAccepted {
        try await client.send(APIEndpoint(path: "/v1/calls/\(callId)/accept", method: .post))
    }

    func declineCall(callId: String) async throws {
        try await client.sendRaw(APIEndpoint(path: "/v1/calls/\(callId)/decline", method: .post))
    }

    func endCall(callId: String) async throws {
        try await client.sendRaw(APIEndpoint(path: "/v1/calls/\(callId)/end", method: .post))
    }

    func rawAudioUploadURL(
        callId: String,
        durationSec: Double,
        sampleRate: Int
    ) async throws -> RawAudioUpload {
        try await client.send(
            APIEndpoint(
                path: "/v1/calls/\(callId)/raw-audio/upload-url",
                method: .post,
                body: RawAudioUploadBody(
                    contentType: "audio/wav",
                    durationSec: durationSec,
                    sampleRate: sampleRate
                )
            )
        )
    }

    func uploadRawAudio(fileURL: URL, to uploadURL: String) async throws {
        try await client.upload(fileURL: fileURL, to: uploadURL, contentType: "audio/wav")
    }

    func completeRawAudio(callId: String, assetId: String) async throws {
        try await client.sendRaw(
            APIEndpoint(
                path: "/v1/calls/\(callId)/raw-audio/complete",
                method: .post,
                body: RawAudioCompleteBody(assetId: assetId)
            )
        )
    }
}
