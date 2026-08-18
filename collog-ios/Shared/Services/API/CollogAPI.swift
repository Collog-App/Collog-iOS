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
