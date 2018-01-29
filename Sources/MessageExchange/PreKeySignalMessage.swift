//
//  PreKeySignalMessage.swift
//  SignalProtocolSwift
//
//  Created by User on 26.10.17.
//  Copyright © 2017 User. All rights reserved.
//

import Foundation

/**
 A `PreKeySignalMessage` can be used to establish a new session.
 */
public struct PreKeySignalMessage {

    /// The message version
    let version: UInt8

    /// The pre key id of the one time key from the other party
    let preKeyId: UInt32?

    /// The id of the signed pre key used for the message
    let signedPreKeyId: UInt32

    /// The base key used for the message
    let baseKey: PublicKey

    /// The identity key of the sender
    let identityKey: PublicKey

    /// The message included in the pre key message
    let message: SignalMessage

    /**
     Create a new pre key message.
     - parameter messageVersion: The message version
     - parameter preKeyId: The pre key id of the one time key from the other party
     - parameter signedPreKeyId: The id of the signed pre key used for the message
     - parameter baseKey: The base key used for the message
     - parameter identityKey: The identity key of the sender
     - parameter message: The message included in the pre key message
     */
    init(messageVersion: UInt8,
         preKeyId: UInt32?,
         signedPreKeyId: UInt32,
         baseKey: PublicKey,
         identityKey: PublicKey,
         message: SignalMessage) {

        self.version = messageVersion
        self.preKeyId = preKeyId
        self.signedPreKeyId = signedPreKeyId
        self.baseKey = baseKey
        self.identityKey = identityKey
        self.message = message
    }

    /**
     Get the serialized message.
     - returns: The serialized message
     - throws: `SignalError` of type `invalidProtoBuf`
    */
    func baseMessage() throws -> CipherTextMessage {
        return CipherTextMessage(type: .preKey, data: try self.data())
    }
}

// MARK: Protocol buffers

extension PreKeySignalMessage {

    /**
     Serialize the message.
     - returns: The serialized message
     - throws: `SignalError` of type `invalidProtoBuf`
    */
    public func data() throws -> Data {
        let ver = (version << 4) | CipherTextMessage.currentVersion
        let obj = try object()
        do {
            return try Data([ver]) + obj.serializedData()
        } catch {
            throw SignalError(.invalidProtoBuf, "Could not serialize PreKeySignalMessage: \(error)")
        }
    }

    /**
     Convert the message to a ProtoBuf object for serialization.
     - returns: The object
     - throws: `SignalError` of type `invalidProtoBuf`
     */
    func object() throws -> Signal_PreKeySignalMessage {
        return try Signal_PreKeySignalMessage.with {
            if let id = self.preKeyId {
                $0.preKeyID = id
            }
            $0.signedPreKeyID = self.signedPreKeyId
            $0.baseKey = self.baseKey.data
            $0.identityKey = self.identityKey.data
            $0.message = try self.message.baseMessage().data
        }
    }

    /**
     Create a `PreKeySignalMessage` from serialized data.
     - note: The following errors can be thrown:
     `invalidProtoBuf`, if the data has missing or corrupt values.
     `invalidVersion`, if the message version is unsupported
     - parameter data: The serialized data.
     - throws: `SignalError` errors
    */
    public init(from data: Data) throws {
        guard data.count > 1 else {
            throw SignalError(.invalidProtoBuf, "Too few bytes in PreKeySignalMessage data")
        }
        let ver = (data[0] & 0xF0) >> 4
        guard ver > CipherTextMessage.unsupportedVersion,
            ver <= CipherTextMessage.currentVersion else {
                throw SignalError(.invalidVersion, "Invalid PreKeySignalMessage version \(ver)")
        }
        let object: Signal_PreKeySignalMessage
        do {
            object = try Signal_PreKeySignalMessage(serializedData: data.advanced(by: 1))
        } catch {
            throw SignalError(.invalidProtoBuf, "Could not create PreKeySignalMessage object: \(error)")
        }
        try self.init(from: object, version: ver)
    }

    /**
     Create a `PreKeySignalMessage` from a ProtoBuf object.
     - note: The following errors can be thrown:
     `invalidProtoBuf`, if the object has missing or corrupt values.
     - parameter object: The serialized data.
     - throws: `SignalError` errors
     */
    init(from object: Signal_PreKeySignalMessage, version: UInt8) throws {
        guard object.hasBaseKey, object.hasMessage, object.hasIdentityKey,
            object.hasSignedPreKeyID else {
                throw SignalError(.invalidProtoBuf, "Missing data in PreKeySignalMessage")
        }
        self.baseKey = try PublicKey(from: object.baseKey)
        self.identityKey = try PublicKey(from: object.identityKey)
        self.message = try SignalMessage(from: object.message)
        self.signedPreKeyId = object.signedPreKeyID
        self.preKeyId = object.hasPreKeyID ? object.preKeyID : nil
        self.version = version
    }
}