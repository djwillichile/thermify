# Builds the animated demo and the social preview image used in the README
# and on GitHub:
#   man/figures/thermify-demo.gif      monthly growing degree-days, Cauquenes
#   man/figures/social-preview.png     1280 x 640 card for link previews
#
# Data: WorldClim 2.1 at 30 arc-seconds for the province of Cauquenes
# (downloaded with worldclim_region()). Run from the package root:
#   Rscript data-raw/readme-figures.R

library(thermify)
library(magick)

data_dir <- Sys.getenv("THERMIFY_DATA", file.path(tempdir(), "readme-data"))
provincia <- cauquenes_boundary("provincia", crs = "EPSG:4326")
comuna <- cauquenes_boundary("comuna", crs = "EPSG:4326")
tmin <- worldclim_region("tmin", provincia, path = data_dir, mask = TRUE)
tmax <- worldclim_region("tmax", provincia, path = data_dir, mask = TRUE)

maps <- thermify_rast(tmin, tmax, output_dir = file.path(tempdir(), "maps"),
                      temporal = "native", indices = c("gdd", "cp"),
                      gdd_methods = "single_sine", base = 10,
                      progress = FALSE)

# Animated GIF: one frame per month on a common colour scale ------------------
gdd <- maps$gdd_single_sine_b10
months <- sprintf("m%02d", 1:12)
zlim <- range(terra::minmax(gdd[[months]]))
pal <- grDevices::hcl.colors(50, "YlOrRd", rev = TRUE)
frames <- image_graph(width = 720, height = 560, res = 96)
for (i in seq_along(months)) {
  plot(gdd[[months[i]]], col = pal, range = zlim, mar = c(2, 2, 3.2, 4.5),
       main = sprintf("Growing degree-days (base 10 degC) - %s",
                      month.name[i]),
       cex.main = 1.25)
  lines(provincia, lwd = 1.4)
  lines(comuna, lty = 2)
}
grDevices::dev.off()
gif <- image_animate(image_quantize(frames, max = 64), fps = 2, optimize = TRUE)
image_write(gif, "man/figures/thermify-demo.gif")

# Social preview: 1280 x 640 ---------------------------------------------------
png_file <- tempfile(fileext = ".png")
grDevices::png(png_file, width = 1280, height = 640, res = 110)
graphics::layout(matrix(c(1, 2, 3), 1), widths = c(1.45, 1, 1))
graphics::par(oma = c(0, 0, 0, 0))
graphics::plot.new()
graphics::text(0.04, 0.78, "thermify", adj = 0, cex = 5.4, font = 2,
               col = "#0B5563")
graphics::text(0.04, 0.54, "Agroclimatic thermal\nindices for R",
               adj = 0, cex = 2.6, font = 2, col = "grey15")
graphics::text(0.04, 0.30, "Degree-days | chilling hours\nUtah units | chill portions",
               adj = 0, cex = 1.9, col = "grey25")
graphics::text(0.04, 0.10, "github.com/djwillichile/thermify", adj = 0,
               cex = 1.6, font = 2, col = "#0B5563")
plot(gdd$season, col = pal, mar = c(1, 1, 3, 4), axes = FALSE,
     main = "Degree-days", cex.main = 1.9)
lines(provincia)
plot(maps$cp_dynamic$season,
     col = grDevices::hcl.colors(50, "YlGn", rev = TRUE),
     mar = c(1, 1, 3, 4), axes = FALSE, main = "Chill portions",
     cex.main = 1.9)
lines(provincia)
grDevices::dev.off()
image_write(image_read(png_file), "man/figures/social-preview.png")
