//
//  ExerciseEnforcer.swift
//  Exercise Enforcer Phone
//
//  Created by Joshua Leonard on 12/11/24.
//

import Foundation
import MediaPlayer

class ExerciseEnforcer: ObservableObject {
    var model: ExerciseEnforcerModel = ExerciseEnforcerModel()
    @Published private(set) var heartRate: Int = 0
    
    var session = AVAudioSession.sharedInstance()
    
    var paused = false
    
    init(){
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
    }
    
    func incrementHeartRate(){
        heartRate += 1
        interruptMusic()
        print(heartRate)
    }
    
    func interruptMusic(){
        if(paused == true){
            try? session.setActive(false, options: AVAudioSession.SetActiveOptions.notifyOthersOnDeactivation)
        }
        else {
            try? session.setActive(true)
        }
        paused = !paused
    }
    
    // MARK - Intents
    func updateHeartRate(){
        //TODO get heart rate
        model.updateHeartRate(heartRate)
        interruptMusic()
    }
}
