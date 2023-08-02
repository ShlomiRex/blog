---
title: "How I optimized Java Swing pixel drawing"
published: true
layout: post
toc: true
---
I was in the process of creating NES emulator.

![](assets/2023-8/Animation5.gif)

This required me to draw pixels on the screen. I was using Java Swing for this.

I was using the following code to draw pixels on the screen:

```java
    for (int tile_row = 0; tile_row < 30; tile_row++) {
        for (int tile_col = 0; tile_col < 32; tile_col++) {
            draw_tile(g, pixel_width, pixel_height, tile_row, tile_col);
        }
    }
    ...
    private void draw_tile(Graphics g, int pixel_width, int pixel_height, int tile_row, int tile_col) {
        ...
        for (int pixel_row = 0; pixel_row < 8; pixel_row ++) {
            for (int pixel_col = 0; pixel_col < 8; pixel_col++) {
                    g.fillRect(
                        (tile_col * 8 + (7- pixel_col)) * pixel_width,
                        (tile_row * 8 + pixel_row) * pixel_height,
                        pixel_width,
                        pixel_height);
            }
        }
    }
```

It seems fine, but we have 32x30 tiles, each tile is 8x8 pixels, so we have 32x30x8x8 = 61440 pixels to draw. This is quite a lot of pixels for each frame.

I run the donkey kong game with Intellij profiler and saw that AWT-EventQueue takes 25% of the CPU time, and AWT-Windows take 22.6% of the CPU time:

![](assets/2023-8/Screenshot 2023-08-02 181610.png)

And the timeline:

![](assets/2023-8/Screenshot 2023-08-02 182121.png)

## The optimization

I decided to use `BufferedImage`. It is a class that represents an image in memory. It has a method `setRGB` that allows to set the color of a pixel.

More importantly, it is efficient. We don't need to immedietly draw the image onto the screen, but we can buffer it in an array, and draw that array instead. 

Here is some of the code I used:

```java
    public PPU(...) {
        ...
        /*
        Each pixel color is 2 bits (0, 1, 2 or 3), which is index inside specific palette.
        There are 64 colors in total.
        Each color is represented by 3 bytes (red, green, blue).
         */
        this.indexColorModel = new IndexColorModel(2, 64, red, green, blue);
        this.bufferedImage = new BufferedImage(256, 240, BufferedImage.TYPE_BYTE_INDEXED, indexColorModel);
    }

    public void draw_frame(Graphics g, int width, int height) {
        for (int tile_row = 0; tile_row < 30; tile_row++) {
            for (int tile_col = 0; tile_col < 32; tile_col++) {
                draw_tile(tile_row, tile_col);
            }
        }
        g.drawImage(bufferedImage, 0, 0, width, height, null);
    }

    private void draw_tile(int tile_row, int tile_col) {
        ...
        bufferedImage.setRGB(
                        (tile_col * 8 + (7- pixel_col)),
                        (tile_row * 8 + pixel_row),
                        c.getRGB());
    }
```

## Results

The result:

![](assets/2023-8/Screenshot 2023-08-02 182657.png)

![](assets/2023-8/Screenshot 2023-08-02 182811.png)

Basically we completly reduced the time of `AWT-Windows` thread from 22.6% to 3.3%, and reduced the time of `AWT-Event-Queue` by 3%.

If we look at the memory allocation, before:

![](assets/2023-8/Screenshot 2023-08-02 183110.png)

And after:

![](assets/2023-8/Screenshot 2023-08-02 183213.png)

We can see that before, we allocated 95% of `AWT-EventQueue` thread in the `draw_tile` function, because of the `fillRect` calls.

After the optimization, we don't allocate anything in `AWT-EventQueue`. All the allocations are done in the thread: `EventDispatchThread.run`.

In terms of real-world performance, checking the task manager, before the optimization:

![](assets/2023-8/Screenshot 2023-08-02 183859.png)

After:

![](assets/2023-8/Screenshot 2023-08-02 184042.png)

* CPU went down from 7.2% to 4.2%
* Memory increased from 251MB to 356MB - which is quite surpricing, perhaps because I store the colors twice?
* The GPU went down from 22% to 7%, which is significant.

## Conclusion

I was able to optimize the pixel drawing by 42% in terms of CPU time, and 68% in terms of GPU time. However the memory went up by 30%.

This is a single example of how I optimize my NES code.

Here is the optimization commit:

[https://github.com/ShlomiRex/nes-emulator-java/commit/367f6eb2bf5dfa6c287efbd91090436cc6f4528e](https://github.com/ShlomiRex/nes-emulator-java/commit/367f6eb2bf5dfa6c287efbd91090436cc6f4528e)

