const create_particles = (class_name, amount) => {
    const svg = document.querySelector(class_name);
    if(!svg) return

    const width = svg.clientWidth;
    const height = svg.clientHeight;

    const centerX = width / 2;
    const centerY = height / 2;

    for (let i = 0; i < amount; i++) {

        // Random position
        const x = Math.random() * width;
        const y = Math.random() * height;

        // Distance from center, normalized to 0 -> 1
        const dx = (x - centerX) / centerX;
        const dy = (y - centerY) / centerY;

        const distance = Math.sqrt(dx * dx + dy * dy);
        const normalizedDistance = Math.min(distance / Math.sqrt(2), 1);

        // Probability of keeping the pixel.
        // Pixels near the center have a much lower chance.
        const probability = Math.pow(normalizedDistance, 2.5);

        if (Math.random() > probability) {
            continue;
        }

        // Pixels become smaller toward the center
        const minSize = 2;
        const maxSize = 12;

        const size =
            minSize +
            Math.pow(normalizedDistance, 1.5) *
            (maxSize - minSize);

        const rect = document.createElementNS(
            "http://www.w3.org/2000/svg",
            "rect"
        );

        rect.setAttribute("x", x);
        rect.setAttribute("y", y);
        rect.setAttribute("width", size);
        rect.setAttribute("height", size);
        rect.setAttribute("fill", "#ff123f");
        rect.classList.add("pixel");
        rect.style.animationDelay = `${Math.random() * 4}s`;
        rect.style.animationDuration = `${3 + Math.random() * 4}s`;

        svg.appendChild(rect);
    }
}
