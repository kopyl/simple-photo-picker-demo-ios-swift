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
    init(_ placement: HandlePlacement, _ handlePositions: Binding<CropHandlePositions>) {
        self.placement = placement
        self._handlePositions = handlePositions
    }

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

class CropHandleManager: ObservableObject {
    @Published private var positions: [Int: CropHandlePositions] = [:]

    func initializeHandlePositions(_ index: Int, _ topY: CGFloat, _ bottomY: CGFloat, _ handleX: CGFloat) {
        if positions[index] == nil {
            positions[index] = CropHandlePositions(topY, bottomY, handleX)
        }
    }
    
    func binding(for index: Int) -> Binding<CropHandlePositions> {
        Binding(
            get: { self.positions[index] ?? CropHandlePositions(0, 0, 0) },
            set: { self.positions[index] = $0 }
        )
    }
}

struct CropHandleView: View {
    let index: Int
    let placement: CropHandle.HandlePlacement
    @ObservedObject var viewModel: CropHandleViewModel
    
    var body: some View {
        ZStack {
            Circle()
                .fill(placement == .top ? .blue : .red)
                .frame(width: HandleSizes.visible.rawValue, height: HandleSizes.visible.rawValue)
            
            Circle()
                .fill(.clear)
                .contentShape(Circle())
        }
        .frame(width: HandleSizes.safeArea.rawValue, height: HandleSizes.safeArea.rawValue)
        .position(getPosition())
        .gesture(
            DragGesture().onChanged { value in
                viewModel.updateHandlePosition(
                    index: index,
                    isTop: placement == .top,
                    newY: value.location.y
                )
            }
        )
    }
    
    private func getPosition() -> CGPoint {
        guard let positions = viewModel.handlePositions[index] else { return .zero }
        return CGPoint(
            x: positions.xPosition,
            y: placement == .top ? positions.top.current : positions.bottom.current
        )
    }
}

class CropHandleViewModel: ObservableObject {
    @Published var handlePositions: [Int: CropHandlePositions] = [:]
    
    func updateHandlePosition(index: Int, isTop: Bool, newY: CGFloat) {
        guard var positions = handlePositions[index] else { return }
        if isTop {
            positions.top.current = newY
        } else {
            positions.bottom.current = newY
        }
        handlePositions[index] = positions
    }
}

struct ImageScrollView: View {
    @Binding var displayImages: [UIImage]
    @Binding var contentPhotoInScrollViewIndex: Int
    
    @StateObject private var handleManager = CropHandleManager()
    
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
                            ZStack {
                                let image = displayImages[index]
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .onAppear {
                                        let imageSize = calculateImageSize(for: image, in: geometry.size)
                                        let topY = (geometry.size.height - imageSize.height) / 2
                                        let bottomY = topY + imageSize.height
                                        let handleX = geometry.size.width / 2
                                        handleManager.initializeHandlePositions(index, topY, bottomY, handleX)
                                    }
                                CropHandle(.top, handleManager.binding(for: index))
                                CropHandle(.bottom, handleManager.binding(for: index))
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                        }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                .scrollTargetLayout()
                .scrollTargetBehavior(.viewAligned)
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
