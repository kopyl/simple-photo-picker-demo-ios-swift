import SwiftUI
import PhotosUI

struct BorderedProminentButtonStyleOverride: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(configuration.isPressed ? .blue.opacity(0.8) : .blue)
            .foregroundColor(.white)
            .cornerRadius(8)
    }
}

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct SaveButton: View {
    @Binding var displayImages: [UIImage]
    @Binding var contentPhotoInScrollViewIndex: Int
    @Binding var wasAtLeastOnePhotoWasEverDisplayed: Bool
    
    init(_ displayImages: Binding<[UIImage]>, _ contentPhotoInScrollViewIndex: Binding<Int>, _ wasAtLeastOnePhotoWasEverDisplayed: Binding<Bool>) {
            self._displayImages = displayImages
            self._contentPhotoInScrollViewIndex = contentPhotoInScrollViewIndex
            self._wasAtLeastOnePhotoWasEverDisplayed = wasAtLeastOnePhotoWasEverDisplayed
        }
    
    var body: some View {
        HStack(spacing: 0){
            if wasAtLeastOnePhotoWasEverDisplayed {
                Button {
                    UIImageWriteToSavedPhotosAlbum(displayImages[contentPhotoInScrollViewIndex], nil, nil, nil)
                } label: {
                    Image(systemName: "arrow.down.square.fill")
                        .font(.system(size: 20))
                    Text("Save")
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue.opacity(0.1))
                .foregroundColor(.blue)
                .controlSize(.large)
                .padding(.leading, 30)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

struct ImageScrollView: View {
    @Binding var displayImages: [UIImage]
    @Binding var contentPhotoInScrollViewIndex: Int
    
    init(_ displayImages: Binding<[UIImage]>, _ contentPhotoInScrollViewIndex: Binding<Int>) {
        self._displayImages = displayImages
        self._contentPhotoInScrollViewIndex = contentPhotoInScrollViewIndex
    }
    
    var body: some View {
        if !displayImages.isEmpty {
            GeometryReader { geometry in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(displayImages, id: \.self) { image in
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .background(GeometryReader { proxy in
                                    Color.clear
                                        .preference(key: ScrollOffsetKey.self, value: proxy.frame(in: .global).origin.x)
                                })
                        }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .scrollTargetLayout()
                .onPreferenceChange(ScrollOffsetKey.self) { contentOffset in
                    let index = Int((contentOffset + geometry.size.width / 2) / geometry.size.width)
                    contentPhotoInScrollViewIndex = min(max(index, 0), displayImages.count - 1)
                }
                .scrollTargetBehavior(.viewAligned)
            }
        }
    }
}

struct PhotosPickerView: View {
    @Binding var selectedItems: [PhotosPickerItem]
    @Binding var displayImages: [UIImage]
    @Binding var wasAtLeastOnePhotoWasEverDisplayed: Bool
    
    init(_ selectedItems: Binding<[PhotosPickerItem]>, _ displayImages: Binding<[UIImage]>, _ wasAtLeastOnePhotoWasEverDisplayed: Binding<Bool>) {
            self._selectedItems = selectedItems
            self._displayImages = displayImages
            self._wasAtLeastOnePhotoWasEverDisplayed = wasAtLeastOnePhotoWasEverDisplayed
        }
    
    var body: some View {
        PhotosPicker(
            selection: $selectedItems,
            selectionBehavior: .ordered,
            photoLibrary: .shared()) {
                HStack{
                    Spacer()
                    Button {
                    }
                    label: {
                        HStack {
                            Image(systemName: "photo.fill")
                                .font(.system(size: 20))
                            Text("Pick a photo")
                        }
                    }
                    .controlSize(.large)
                    .padding(.trailing, 30)
                    .disabled(true)
                    .buttonStyle(BorderedProminentButtonStyleOverride())
                }
            }
            .onChange(of: selectedItems) { oldval, newval in
                Task {
                    if oldval.count == 0 && displayImages.count > 0 {
                        displayImages.removeAll()
                    }
                    for selectedItemOrder in 0..<selectedItems.count {
                        if let data = try? await selectedItems[selectedItemOrder].loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            withAnimation(.linear(duration: 0.25)) {
                                displayImages.append(image)
                            }
                        }
                    }
                    withAnimation(.linear(duration: 0.25)) {
                        wasAtLeastOnePhotoWasEverDisplayed = true
                    }
                    selectedItems = []
                }
            }
    }
}

struct ContentView: View {
    @State private var displayImages: [UIImage] = []
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var wasAtLeastOnePhotoWasEverDisplayed = false
    @State private var contentPhotoInScrollViewIndex: Int = -1
    
    var body: some View {
        VStack {

            ImageScrollView($displayImages, $contentPhotoInScrollViewIndex)
            if displayImages.isEmpty { Spacer() }
            HStack(spacing: 0){
                SaveButton($displayImages, $contentPhotoInScrollViewIndex, $wasAtLeastOnePhotoWasEverDisplayed)
                PhotosPickerView($selectedItems, $displayImages, $wasAtLeastOnePhotoWasEverDisplayed)
            }
            
        }
    }
}

#Preview {
    ContentView()
}
