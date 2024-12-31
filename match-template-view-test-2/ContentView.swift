import SwiftUI
import PhotosUI

enum HandleSizes: CGFloat {
    case visible = 30
    case safeArea = 50
}

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

struct CropHandlePositions {
    var initialTop: CGFloat
    var currentTop: CGFloat
    var initialBottom: CGFloat
    var currentBottom: CGFloat
    var xPosition: CGFloat

    init(_ _initialTop: CGFloat, _ _initialBottom: CGFloat, _ _xPosition: CGFloat) {
        self.initialTop = _initialTop
        self.currentTop = _initialTop
        
        self.initialBottom = _initialBottom
        self.currentBottom = _initialBottom
        
        self.xPosition = _xPosition
    }

    var top: (initial: CGFloat, current: CGFloat, min: CGFloat, max: CGFloat) {
        get {
            let minTop = min(initialTop, currentTop)
            let maxTop = max(initialTop, currentTop)
            return (initialTop, currentTop, minTop, maxTop)
        }
        set {
            var modifiedValue = newValue
            
            if modifiedValue.current >= bottom.current {
                modifiedValue.current = bottom.current
            }
            else if modifiedValue.current >= bottom.initial {
                modifiedValue.current = bottom.initial
            }
            else {
                initialTop = modifiedValue.initial
                currentTop = modifiedValue.current
            }
        }
    }

    var bottom: (initial: CGFloat, current: CGFloat, min: CGFloat, max: CGFloat) {
        get {
            let minBottom = min(initialBottom, currentBottom)
            let maxBottom = max(initialBottom, currentBottom)
            return (initialBottom, currentBottom, minBottom, maxBottom)
        }
        set {
            var modifiedValue = newValue
            
            if modifiedValue.current <= top.current {
                modifiedValue.current = top.current
            }
            else if modifiedValue.current <= top.initial {
                modifiedValue.current = top.initial
            }
            else {
                initialBottom = modifiedValue.initial
                currentBottom = modifiedValue.current
            }
            
        }
    }
}


struct CropHandle: View {
    enum HandlePlacement {
        case top, bottom
    }
    var placement: HandlePlacement
    @Binding var handlePositions: CropHandlePositions

    var body: some View {
        ZStack {
            Circle()
                .fill(placement == .top ? .blue : .red)
                .frame(width: HandleSizes.visible.rawValue, height: HandleSizes.visible.rawValue)
                
            Circle()
                .fill(.clear)
                .contentShape(Circle())
        }
        .frame(width: HandleSizes.safeArea.rawValue, height: HandleSizes.safeArea.rawValue, alignment: .center)
        .position(
            x: handlePositions.xPosition,
            y: placement == .top ? handlePositions.top.max : handlePositions.bottom.min
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    if placement == .top {
                        handlePositions.top.current = value.location.y
                    } else {
                        handlePositions.bottom.current = value.location.y
                    }
                }
        )
    }
}


struct ImageScrollView: View {
    @Binding var displayImages: [UIImage]
    @Binding var contentPhotoInScrollViewIndex: Int
    
    @State private var handlePositions: [Int: CropHandlePositions] = [:]
    
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
                                            let handleX = geometry.size.width / 2
                                            handlePositions[index] = CropHandlePositions(topPositionY, bottomPositionY, handleX)
                                        }
                                    
                                    if let hp = handlePositions[index] {
                                        CropHandle(placement: .top, handlePositions: Binding(
                                            get: { hp },
                                            set: { handlePositions[index] = $0 }
                                        ))
                                        CropHandle(placement: .bottom, handlePositions: Binding(
                                            get: { hp },
                                            set: { handlePositions[index] = $0 }
                                        ))
                                    }
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
                        if handlePositions[index]?.top.current == nil &&
                        handlePositions[index]?.bottom.current == nil {
                            let imageSize = calculateImageSize(for: displayImages[index], in: geometry.size)
                            handlePositions[index]?.top.current = (geometry.size.height - imageSize.height) / 2
                            handlePositions[index]?.bottom.current = handlePositions[index]?.top.current ?? 0.0 + imageSize.height
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
