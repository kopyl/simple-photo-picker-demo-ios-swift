import SwiftUI
import PhotosUI

enum HandleSizes: CGFloat {
    case sign = 6
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

    init(_ _initialTop: CGFloat, _ _initialBottom: CGFloat) {
        self.initialTop = _initialTop
        self.currentTop = _initialTop
        
        self.initialBottom = _initialBottom
        self.currentBottom = _initialBottom
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

struct ImageScrollView: View {
    @Binding var displayImages: [UIImage]
    @Binding var contentPhotoInScrollViewIndex: Int
    
    @Binding var handlePositions: [Int: CropHandlePositions]
    
    init(_ displayImages: Binding<[UIImage]>, _ contentPhotoInScrollViewIndex: Binding<Int>, _ handlePositions: Binding<[Int: CropHandlePositions]>) {
        self._displayImages = displayImages
        self._contentPhotoInScrollViewIndex = contentPhotoInScrollViewIndex
        self._handlePositions = handlePositions
    }
    
    private func calculatedOffsetForTopImageCroppingOverlay(for index: Int) -> CGSize {
            let currentTop = handlePositions[index]?.top.current ?? 0
            let minTop = handlePositions[index]?.top.min ?? 0
            let offsetValue = (currentTop - minTop) - (currentTop - minTop) / 2
            return CGSize(width: 0, height: offsetValue)
        }
    
    private func calculatedOffsetForBottomImageCroppingOverlay(for index: Int) -> CGSize {
            let currentBottom = handlePositions[index]?.bottom.current ?? 0
            let maxBottom = handlePositions[index]?.bottom.max ?? 0
            let offsetValue = (currentBottom - maxBottom) - (currentBottom - maxBottom) / 2
            return CGSize(width: 0, height: offsetValue)
        }
    
    private func calculatedHeightForTopImageCroppingOverlay(for index: Int) -> CGFloat {
        let currentTop = handlePositions[index]?.top.current ?? 0
        let minTop = handlePositions[index]?.top.min ?? 0
        let height = currentTop - minTop
        return height
    }
    
    private func calculatedHeightForBottomImageCroppingOverlay(for index: Int) -> CGFloat {
        let currentBottom = handlePositions[index]?.bottom.current ?? 0
        let maxBottom = handlePositions[index]?.bottom.max ?? 0
        let height = maxBottom - currentBottom
        return height
    }
    
    private func calculatedPositionForTopImageCroppingOverlay(for index: Int) -> CGFloat {
        let minTop = handlePositions[index]?.top.min ?? 0
        return minTop
    }
    
    private func calculatedPositionForBottomImageCroppingOverlay(for index: Int) -> CGFloat {
        let maxBottom = handlePositions[index]?.bottom.max ?? 0
        return maxBottom
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
                                            handlePositions[index] = CropHandlePositions(topPositionY, bottomPositionY)
                                            print(2)
                                        }
                                    Rectangle()
                                        .fill(Color("overlay-crop-color"))
                                        .frame(
                                            width: geometry.size.width,
                                            height: calculatedHeightForTopImageCroppingOverlay(for: index)
                                        )
                                        .position(
                                            x: geometry.size.width / 2,
                                            y: calculatedPositionForTopImageCroppingOverlay(for: index)
                                        )
                                        .offset(calculatedOffsetForTopImageCroppingOverlay(for: index))

                                    ZStack {
                                        ZStack {
                                            Circle()
                                                .fill(.blue)
                                                .frame(width: HandleSizes.visible.rawValue, height: HandleSizes.visible.rawValue)
                                            Circle()
                                                .fill(.white)
                                                .frame(width: HandleSizes.sign.rawValue, height: HandleSizes.sign.rawValue)
                                        }
                                            
                                        Rectangle()
                                            .fill(.clear)
                                            .contentShape(Rectangle())
                                    }
                                    .frame(width: geometry.size.width, height: HandleSizes.safeArea.rawValue, alignment: .center)
                                    .position(
                                        x: geometry.size.width / 2,
                                        y: handlePositions[index]?.top.max ?? 0
                                    )
                                    .gesture(
                                        DragGesture()
                                            .onChanged { value in
                                                handlePositions[index]?.top.current = value.location.y
                                            }
                                    )
                                    
                                    Rectangle()
                                        .fill(Color("overlay-crop-color"))
                                        .frame(
                                            width: geometry.size.width,
                                            height: calculatedHeightForBottomImageCroppingOverlay(for: index)
                                        )
                                        .position(
                                            x: geometry.size.width / 2,
                                            y: calculatedPositionForBottomImageCroppingOverlay(for: index)
                                        )
                                        .offset(calculatedOffsetForBottomImageCroppingOverlay(for: index))
                                    
                                    ZStack {
                                        ZStack {
                                            Circle()
                                                .fill(.blue)
                                                .frame(width: HandleSizes.visible.rawValue, height: HandleSizes.visible.rawValue)
                                            Circle()
                                                .fill(.white)
                                                .frame(width: HandleSizes.sign.rawValue, height: HandleSizes.sign.rawValue)
                                        }
                                            
                                        Rectangle()
                                            .fill(.clear)
                                            .contentShape(Rectangle())
                                    }
                                    .frame(width: geometry.size.width, height: HandleSizes.safeArea.rawValue, alignment: .center)
                                    .position(
                                        x: geometry.size.width / 2,
                                        y: handlePositions[index]?.bottom.min ?? 0
                                    )
                                    .gesture(
                                        DragGesture()
                                            .onChanged { value in
                                                handlePositions[index]?.bottom.current = value.location.y
                                            }
                                            .onEnded { value in
                                                print(2)
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
            matching: .not(.any(of: [.bursts, .cinematicVideos, .depthEffectPhotos, .livePhotos, .screenRecordings, .screenRecordings, .slomoVideos, .timelapseVideos, .videos])),
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

// sounrce:
// https://gist.github.com/schickling/b5d86cb070130f80bb40?permalink_comment_id=2894406#gistcomment-2894406
extension UIImage {
    func fixedOrientation() -> UIImage? {
        guard imageOrientation != UIImage.Orientation.up else {
            return self.copy() as? UIImage
        }
        
        guard let cgImage = self.cgImage else {
            return nil
        }
        
        guard let colorSpace = cgImage.colorSpace, let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: cgImage.bitsPerComponent, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        
        var transform: CGAffineTransform = CGAffineTransform.identity
        
        switch imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: size.height)
            transform = transform.rotated(by: CGFloat.pi)
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.rotated(by: CGFloat.pi / 2.0)
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: size.height)
            transform = transform.rotated(by: CGFloat.pi / -2.0)
        case .up, .upMirrored:
            break
        @unknown default:
            break
        }

        switch imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: size.height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .up, .down, .left, .right:
            break
        @unknown default:
            break
        }
        
        ctx.concatenate(transform)
        
        switch imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.height, height: size.width))
        default:
            ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
            break
        }
        
        guard let newCGImage = ctx.makeImage() else { return nil }
        return UIImage.init(cgImage: newCGImage, scale: 1, orientation: .up)
    }
}

func cropImage(_ image: UIImage, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) -> UIImage? {
    let rectToCrop = CGRect(x: x, y: y, width: width, height: height)
    let rect = CGRect(x: rectToCrop.origin.x, y: rectToCrop.origin.y, width: rectToCrop.width, height: rectToCrop.height)

    guard let cropped = image.fixedOrientation()?.cgImage?.cropping(to: rect) else {
        return nil
    }
    return UIImage(cgImage: cropped, scale: image.scale, orientation: .up)
}

struct ContentView: View {
    @State private var displayImages: [UIImage] = []
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var contentPhotoInScrollViewIndex: Int = -1
    @State private var handlePositions: [Int: CropHandlePositions] = [:]
    
    var body: some View {
        VStack {
            ImageScrollView($displayImages, $contentPhotoInScrollViewIndex, $handlePositions)
            Spacer()
            HStack(spacing: 0){
                if contentPhotoInScrollViewIndex != -1 {
                    ButtonStyled("arrow.down.square", "Save", .secondary, .leadingPadding) {
                        if let currentPhotoCropPosition = handlePositions[contentPhotoInScrollViewIndex] {
                            let currentPhoto = displayImages[contentPhotoInScrollViewIndex]
                            
                            let pictureMiniatureHeight = currentPhotoCropPosition.bottom.max - currentPhotoCropPosition.top.min
                            let ratioMiniToReal = currentPhoto.size.height / pictureMiniatureHeight
                            let pictureMiniatureCropFromTop = currentPhotoCropPosition.top.current - currentPhotoCropPosition.top.min
                            let remaningMiniatureHeight = pictureMiniatureHeight - pictureMiniatureCropFromTop
                            let pictureMiniatureCropFromBottom = currentPhotoCropPosition.bottom.max - currentPhotoCropPosition.bottom.current
                            let cropFromBottom = pictureMiniatureCropFromBottom * ratioMiniToReal
                            let startCroppintAt = pictureMiniatureCropFromTop * ratioMiniToReal
                            let remainingHeight = remaningMiniatureHeight * ratioMiniToReal - cropFromBottom
                            if let imageCropped = cropImage(currentPhoto,
                                    x: 0,
                                    y: startCroppintAt,
                                    width: currentPhoto.size.width,
                                    height: remainingHeight
                            ) {
                                UIImageWriteToSavedPhotosAlbum(imageCropped, nil, nil, nil)
                            }
                        }
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
