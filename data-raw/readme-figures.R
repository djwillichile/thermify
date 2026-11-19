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
# Also needs the png package (to read the logo).

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
# GitHub crops link previews unpredictably and recommends keeping everything
# important 40 pt (80 px at this size) from every edge: the outer margin
# below (omi, in inches at 110 dpi) leaves at least 80 px on each side.
png_file <- tempfile(fileext = ".png")
grDevices::png(png_file, width = 1280, height = 640, res = 110)
graphics::layout(matrix(c(1, 2, 3), 1), widths = c(1.75, 1, 1))
graphics::par(omi = rep(80 / 110, 4))
graphics::par(mar = c(0, 0, 0, 0))
graphics::plot.new()
# Hex logo in the top-left corner, keeping its aspect ratio, and the name
# next to it.
logo <- png::readPNG("man/figures/logo.png")
logo_h <- 0.34
logo_w <- logo_h * graphics::par("pin")[2] / graphics::par("pin")[1] *
  dim(logo)[2] / dim(logo)[1]
graphics::rasterImage(logo, 0, 1 - logo_h, logo_w, 1)
graphics::text(logo_w + 0.04, 1 - logo_h / 2, "thermify", adj = 0, cex = 5,
               font = 2, col = "#0B5563")
graphics::text(0, 0.49, "Agroclimatic thermal\nindices for R",
               adj = 0, cex = 3.1, font = 2, col = "grey15")
graphics::text(0, 0.245, "Degree-days | chilling hours\nUtah units | chill portions",
               adj = 0, cex = 2.2, col = "grey25")
graphics::text(0, 0.04, "github.com/djwillichile/thermify", adj = 0,
               cex = 1.85, font = 2, col = "#0B5563")
legend_style <- list(cex = 1.6)
plot(gdd$season, col = pal, mar = c(0.5, 0.5, 2.6, 4.4), axes = FALSE,
     main = "Degree-days", cex.main = 1.7, plg = legend_style)
lines(provincia)
plot(maps$cp_dynamic$season,
     col = grDevices::hcl.colors(50, "YlGn", rev = TRUE),
     mar = c(0.5, 0.5, 2.6, 4.4), axes = FALSE, main = "Chill portions",
     cex.main = 1.7, plg = legend_style)
lines(provincia)
grDevices::dev.off()
image_write(image_read(png_file), "man/figures/social-preview.png")
