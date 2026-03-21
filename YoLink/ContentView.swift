//
//  ContentView.swift
//  YoLink
//
//  Created by Rae Wang on 3/12/26.
//

import SwiftUI

struct ContentView: View {
    @State private var authViewModel = AuthViewModel()
    
    var body: some View {
        Group {
            if authViewModel.showMainTabView {
                MainTabView()
            } else {
                LoginView(viewModel: authViewModel)
            }
        }
    }
}

#Preview {
    ContentView()
}
