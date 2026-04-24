import Foundation
import AVFoundation
import AudioToolbox

enum SoundType: String {
    case tick = "custom_tick"
    case complete = "custom_complete"
}

class SoundService {
    static let shared = SoundService()
    
    private var tickPlayer: AVAudioPlayer?
    private var completePlayer: AVAudioPlayer?
    
    private init() {
        setupAudioSession()
        reloadPlayers()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session: \(error)")
        }
    }
    
    func reloadPlayers() {
        tickPlayer = preparePlayer(for: .tick)
        completePlayer = preparePlayer(for: .complete)
    }
    
    private func preparePlayer(for type: SoundType) -> AVAudioPlayer? {
        let fileName = UserDefaults.standard.string(forKey: type.rawValue)
        let url: URL?
        
        if let fileName = fileName {
            let path = getDocumentsDirectory().appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: path.path) {
                url = path
            } else {
                url = nil
            }
        } else {
            url = nil // Fallback to system sound or bundle later
        }
        
        if let url = url {
            return try? AVAudioPlayer(contentsOf: url)
        }
        return nil
    }
    
    func playTick() {
        guard UserDefaults.standard.bool(forKey: "isTickingEnabled") else { return }
        
        if let player = tickPlayer {
            player.volume = 1.0
            player.play()
        } else {
            // Fallback to a louder system sound (1057 is a slightly louder tick)
            AudioServicesPlaySystemSound(1057)
        }
    }
    
    func playDing() {
        guard UserDefaults.standard.bool(forKey: "isCompletionSoundEnabled") else { return }
        
        if let player = completePlayer {
            player.volume = 1.0
            player.play()
        } else {
            AudioServicesPlaySystemSound(1000)
        }
    }
    
    func saveCustomSound(from url: URL, for type: SoundType) -> Bool {
        let fileName = "\(type.rawValue).\(url.pathExtension)"
        let destination = getDocumentsDirectory().appendingPathComponent(fileName)
        
        // Ensure access to security scoped resource
        guard url.startAccessingSecurityScopedResource() else { return false }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: url, to: destination)
            UserDefaults.standard.set(fileName, forKey: type.rawValue)
            reloadPlayers()
            return true
        } catch {
            print("Failed to save custom sound: \(error)")
            return false
        }
    }
    
    func removeCustomSound(for type: SoundType) {
        if let fileName = UserDefaults.standard.string(forKey: type.rawValue) {
            let path = getDocumentsDirectory().appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: path)
        }
        UserDefaults.standard.removeObject(forKey: type.rawValue)
        reloadPlayers()
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
