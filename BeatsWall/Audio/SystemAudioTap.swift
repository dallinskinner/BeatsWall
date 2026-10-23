//
//  SystemAudioTap.swift
//  BeatsWall
//

import AudioToolbox
import CoreAudio
import Foundation

nonisolated struct AudioTapError: LocalizedError {
    let operation: String
    let status: OSStatus

    var errorDescription: String? { "\(operation) failed (OSStatus \(status))." }
}

/// Captures everything the Mac is playing with a Core Audio process tap, wrapped in a
/// private aggregate device, and feeds it to an `AudioAnalyzer`.
nonisolated final class SystemAudioTap: @unchecked Sendable {
    private let analyzer: AudioAnalyzer
    private let queue = DispatchQueue(label: "julian.BeatsWall.audio-tap", qos: .userInteractive)
    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?

    init(analyzer: AudioAnalyzer) {
        self.analyzer = analyzer
    }

    func start() throws {
        let description = CATapDescription(stereoGlobalTapButExcludeProcesses: [])
        description.uuid = UUID()
        description.name = "BeatsWall"
        description.isPrivate = true
        description.muteBehavior = .unmuted

        try Self.check(AudioHardwareCreateProcessTap(description, &tapID), "Creating the system audio tap")
        do {
            let outputUID = try Self.defaultOutputDeviceUID()
            let aggregate: [String: Any] = [
                kAudioAggregateDeviceNameKey: "BeatsWall Tap",
                kAudioAggregateDeviceUIDKey: UUID().uuidString,
                kAudioAggregateDeviceMainSubDeviceKey: outputUID,
                kAudioAggregateDeviceIsPrivateKey: true,
                kAudioAggregateDeviceIsStackedKey: false,
                kAudioAggregateDeviceTapAutoStartKey: true,
                kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: outputUID]],
                kAudioAggregateDeviceTapListKey: [[
                    kAudioSubTapDriftCompensationKey: true,
                    kAudioSubTapUIDKey: description.uuid.uuidString,
                ]],
            ]
            try Self.check(AudioHardwareCreateAggregateDevice(aggregate as CFDictionary, &aggregateID), "Creating the capture device")

            let format: AudioStreamBasicDescription = try Self.property(of: tapID, kAudioTapPropertyFormat, initial: AudioStreamBasicDescription())
            let sampleRate = format.mSampleRate
            let analyzer = analyzer
            try Self.check(AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregateID, queue) { _, input, _, _, _ in
                let buffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
                guard let buffer = buffers.first, let data = buffer.mData else { return }
                let channels = max(Int(buffer.mNumberChannels), 1)
                let frames = Int(buffer.mDataByteSize) / (MemoryLayout<Float>.size * channels)
                analyzer.process(interleaved: data.assumingMemoryBound(to: Float.self), frames: frames, channels: channels, sampleRate: sampleRate)
            }, "Creating the audio callback")
            try Self.check(AudioDeviceStart(aggregateID, ioProcID), "Starting audio capture")
        } catch {
            stop()
            throw error
        }
    }

    func stop() {
        if aggregateID != kAudioObjectUnknown {
            if let ioProcID {
                AudioDeviceStop(aggregateID, ioProcID)
                AudioDeviceDestroyIOProcID(aggregateID, ioProcID)
            }
            AudioHardwareDestroyAggregateDevice(aggregateID)
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
        }
        ioProcID = nil
        aggregateID = AudioObjectID(kAudioObjectUnknown)
        tapID = AudioObjectID(kAudioObjectUnknown)
    }

    private static func defaultOutputDeviceUID() throws -> String {
        let device: AudioObjectID = try property(
            of: AudioObjectID(kAudioObjectSystemObject),
            kAudioHardwarePropertyDefaultOutputDevice,
            initial: AudioObjectID(kAudioObjectUnknown)
        )
        let uid: Unmanaged<CFString>? = try property(of: device, kAudioDevicePropertyDeviceUID, initial: nil)
        guard let uid else { throw AudioTapError(operation: "Finding the output device", status: kAudioHardwareBadDeviceError) }
        return uid.takeRetainedValue() as String
    }

    private static func property<T>(of object: AudioObjectID, _ selector: AudioObjectPropertySelector, initial: T) throws -> T {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<T>.size)
        var value = initial
        let status = withUnsafeMutablePointer(to: &value) {
            AudioObjectGetPropertyData(object, &address, 0, nil, &size, $0)
        }
        try check(status, "Reading an audio property")
        return value
    }

    private static func check(_ status: OSStatus, _ operation: String) throws {
        guard status == noErr else { throw AudioTapError(operation: operation, status: status) }
    }
}
