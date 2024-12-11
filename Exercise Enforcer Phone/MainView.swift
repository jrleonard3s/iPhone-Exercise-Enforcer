//
//  MainView.swift
//  Exercise Enforcer Phone
//
//  Created by Joshua Leonard on 12/10/24.
//

import SwiftUI

struct MainView: View {
    var viewModel: ExerciseEnforcer
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}







#Preview {
    MainView(exerciseEnforcer: ExerciseEnforcer())
}
