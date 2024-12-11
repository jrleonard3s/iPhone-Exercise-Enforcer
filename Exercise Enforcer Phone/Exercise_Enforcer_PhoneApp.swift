//
//  Exercise_Enforcer_PhoneApp.swift
//  Exercise Enforcer Phone
//
//  Created by Joshua Leonard on 12/10/24.
//

import SwiftUI

@main
struct Exercise_Enforcer_PhoneApp: App {
    @StateObject var exerciseEnforcer = ExerciseEnforcer()
    
    var body: some Scene {
        WindowGroup {
            MainView(viewModel: exerciseEnforcer)
        }
    }
}


