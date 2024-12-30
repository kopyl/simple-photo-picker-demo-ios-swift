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

struct ContentView: View {
    @State private var displayImages: [UIImage] = []
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var isPhotosDisplayed = false
    @State private var wasAtLeastOnePhotoWasEverDisplayed = false
    @State private var contentPhotoInScrollViewIndex: Int = -1
    
    var body: some View {
        VStack {

            if isPhotosDisplayed {
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
                        .onChange(of: geometry.frame(in: .global)) {
                            if displayImages.count == 0 {
                                isPhotosDisplayed = false
                                contentPhotoInScrollViewIndex = -1
                            }
                        }
                        .onChange(of: contentPhotoInScrollViewIndex) {
                            print(contentPhotoInScrollViewIndex)
                        }

                    .onPreferenceChange(ScrollOffsetKey.self) { contentOffset in
                        let index = Int((contentOffset + geometry.size.width / 2) / geometry.size.width)
                        contentPhotoInScrollViewIndex = min(max(index, 0), displayImages.count - 1)
                    }
                    .scrollTargetBehavior(.viewAligned)
                }
            }
            if !isPhotosDisplayed {
                Spacer()
            }
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
                    .foregroundColor(/*@START_MENU_TOKEN@*/.blue/*@END_MENU_TOKEN@*/)
                    .controlSize(.large)
                    .padding(.leading, 30)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
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

                        .onChange(of: selectedItems) { oldval, newval in
                            Task {
                                if oldval.count == 0 && displayImages.count > 0 {
                                    displayImages.removeAll()
                                }
                                for selectedItemOrder in 0..<selectedItems.count {
                                    if let data = try? await selectedItems[selectedItemOrder].loadTransferable(type: Data.self),
                                       let image = UIImage(data: data) {
                                            displayImages.append(image)
                                        }
                                }
                                withAnimation(.linear(duration: 0.25)) {
                                    isPhotosDisplayed = true
                                    wasAtLeastOnePhotoWasEverDisplayed = true
                                }
                                selectedItems = []
                            }
                        }
                        
                    }
            }
            
        }
    }
}

#Preview {
    ContentView()
}
