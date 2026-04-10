
import SwiftUI

struct EventItem: Identifiable {
    let id = UUID()
    var name: String
    var location: String
    var date: Date
    var coverImage: Image?
}
