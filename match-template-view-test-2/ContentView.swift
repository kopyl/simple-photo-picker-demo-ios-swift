import SwiftUI
import PhotosUI

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ButtonStyled: View {
    enum Importance {
        case primary
        case secondary
    }
    
    enum Padding {
        case leadingPadding
        case trailingPadding
    }
    
    var icon: String
    var text: String
    var importance: Importance
    var padding: Padding
    var action: ()->() = {}
    
    init(
        _ icon: String,
        _ text: String,
        _ _is: Importance = .primary,
        _ padding: Padding = .leadingPadding,
        action: @escaping ()->() = {})
    {
        self.icon = icon
        self.text = text
        self.importance = _is
        self.padding = padding
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon + ".fill")
                    .font(.system(size: 20))
                Text(text)
                    .font(.system(size: 16))
            }
        }
        .padding()
        .background(importance == .secondary ? .blue.opacity(0.1) : .blue)
        .foregroundColor(importance == .secondary ? .blue : .white)
        .cornerRadius(8)
        .opacity(1)
        .disabled(importance == .secondary ? false : true)
        .controlSize(.large)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .padding(padding == .leadingPadding ? Edge.Set.leading : Edge.Set.trailing, 30)
    }
}

struct ImageScrollView: View {
    @Binding var displayImages: [UIImage]
    @Binding var contentPhotoInScrollViewIndex: Int
    
    @State private var topPositions: [Int: CGFloat] = [:]
    @State private var bottomPositions: [Int: CGFloat] = [:]
    
    init(_ displayImages: Binding<[UIImage]>, _ contentPhotoInScrollViewIndex: Binding<Int>) {
        self._displayImages = displayImages
        self._contentPhotoInScrollViewIndex = contentPhotoInScrollViewIndex
    }
    
    var body: some View {
        if !displayImages.isEmpty {
            GeometryReader { geometry in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(displayImages.indices, id: \.self) { index in
                            GeometryReader { imageGeometry in
                                ZStack {
                                    Image(uiImage: displayImages[index])
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: geometry.size.width, height: geometry.size.height)
                                        .onAppear{
                                            let imageSize = calculateImageSize(for: displayImages[index], in: geometry.size)
                                            let topPositionY = (geometry.size.height - imageSize.height) / 2
                                            let bottomPositionY = topPositionY + imageSize.height
                                            
                                            topPositions[index] = topPositionY
                                            bottomPositions[index] = bottomPositionY
                                        }

                                    Circle()
                                        .fill(Color.blue)
                                        .frame(width: 30, height: 30)
                                        .position(
                                            x: geometry.size.width / 2,
                                            y: topPositions[index] ?? 0
                                        )
                                        .gesture(
                                            DragGesture()
                                                .onChanged { value in
                                                    topPositions[index] = max(0, min(topPositions[index] ?? 0, value.location.y))
                                                }
                                        )

                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 30, height: 30)
                                        .position(
                                            x: geometry.size.width / 2,
                                            y: bottomPositions[index] ?? 0
                                        )
                                        .gesture(
                                            DragGesture()
                                                .onChanged { value in
                                                    bottomPositions[index] = max(topPositions[index] ?? 0, min(geometry.size.height, value.location.y))
                                                }
                                        )
                                }
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                        }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .scrollTargetLayout()
                .scrollTargetBehavior(.viewAligned)
                .onAppear {
                    for index in displayImages.indices {
                        if topPositions[index] == nil && bottomPositions[index] == nil {
                            let imageSize = calculateImageSize(for: displayImages[index], in: geometry.size)
                            topPositions[index] = (geometry.size.height - imageSize.height) / 2
                            bottomPositions[index] = topPositions[index]! + imageSize.height
                        }
                    }
                }
                .onPreferenceChange(ScrollOffsetKey.self) { contentOffset in
                    let index = Int((contentOffset + geometry.size.width / 2) / geometry.size.width)
                    contentPhotoInScrollViewIndex = min(index, displayImages.count - 1)
                }
            }
        }
    }
    
    private func calculateImageSize(for image: UIImage, in containerSize: CGSize) -> CGSize {
        let aspectRatio = image.size.width / image.size.height
        if containerSize.width / containerSize.height > aspectRatio {
            let height = containerSize.height
            let width = height * aspectRatio
            return CGSize(width: width, height: height)
        } else {
            let width = containerSize.width
            let height = width / aspectRatio
            return CGSize(width: width, height: height)
        }
    }
}


struct PhotosPickerView: View {
    @Binding var selectedItems: [PhotosPickerItem]
    @Binding var displayImages: [UIImage]
    @Binding var contentPhotoInScrollViewIndex: Int
    
    init(_ selectedItems: Binding<[PhotosPickerItem]>, _ displayImages: Binding<[UIImage]>, _ contentPhotoInScrollViewIndex: Binding<Int>) {
            self._selectedItems = selectedItems
            self._displayImages = displayImages
            self._contentPhotoInScrollViewIndex = contentPhotoInScrollViewIndex
        }
    
    var body: some View {
        PhotosPicker(
            selection: $selectedItems,
            selectionBehavior: .ordered,
            photoLibrary: .shared()) {
                HStack{
                    ButtonStyled("photo", "Pick a photo", .primary, .trailingPadding
                    )
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
                        contentPhotoInScrollViewIndex = displayImages.count - 1
                    }
                    selectedItems = []
                }
            }
    }
}

struct ContentView: View {
    @State private var displayImages: [UIImage] = []
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var contentPhotoInScrollViewIndex: Int = -1
    @State private var cropPositions: [CGFloat] = []
    
    var body: some View {
        VStack {
            ImageScrollView($displayImages, $contentPhotoInScrollViewIndex)
            Spacer()
            HStack(spacing: 0){
                if contentPhotoInScrollViewIndex != -1 {
                    ButtonStyled("arrow.down.square", "Save", .secondary, .leadingPadding) {
                        UIImageWriteToSavedPhotosAlbum(displayImages[displayImages.count - 1 - contentPhotoInScrollViewIndex], nil, nil, nil)
                       }
                }
                Spacer()
                PhotosPickerView($selectedItems, $displayImages, $contentPhotoInScrollViewIndex)
            }
        }
    }
}

#Preview {
    ContentView()
}
