# ------------------------------------------------------------------------------
# STAGE 1: Main {renv} image with all packages + Stan
# ------------------------------------------------------------------------------
FROM rocker/rstudio:4.4.1 AS renv-base

ARG PROJECT="lemon-lucifer"

# Install system dependencies
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends \
    # Determined by {pak} with ./misc/determine-sysreqs.R
    make pandoc libcurl4-openssl-dev libssl-dev libicu-dev zlib1g-dev libx11-dev cmake xz-utils libjpeg-dev libpng-dev libxml2-dev libglpk-dev libfontconfig1-dev libfreetype6-dev libfribidi-dev libharfbuzz-dev libtiff-dev libgdal-dev gdal-bin libgeos-dev libproj-dev libsqlite3-dev libudunits2-dev \
    # For compiling things
    build-essential \
    clang-3.6 \
    # For downloading things
    curl \
    # For dvisvgm ghostscript-y things
    ghostscript \
    # All done
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install general non-{renv} packages
RUN R -e "install.packages(c('rstudioapi'), \
            repos = c(CRAN = 'https://packagemanager.posit.co/cran/latest'))"

# Copy core {renv} things into the container
RUN mkdir -p /home/rstudio/${PROJECT}/renv/cache && chown rstudio:rstudio /home/rstudio/${PROJECT}
WORKDIR /home/rstudio/${PROJECT}
COPY ../renv.lock renv.lock
COPY ../.Rprofile .Rprofile
COPY ../renv/activate.R renv/activate.R
COPY ../renv/settings.json renv/settings.json
COPY ../renv/.gitignore renv/.gitignore

# Install all {renv} packages
ENV RENV_PATHS_CACHE renv/cache
ENV RENV_DOWNLOAD_METHOD libcurl

# This is supposed to happen automatically as part of `renv::restore()` below,
# since {cmdstanr} is in the lockfile, but [due to an issue with
# {renv}](https://github.com/rstudio/renv/issues/1961) (fixed in the development
# version as of 2024-08-06), it doesn't install correctly because it is hosted
# at <https://stan-dev.r-universe.dev> instead of CRAN. So for now, until the
# next stable release of {renv}, it's easiest to install {cmdstanr} in a
# separate step.
RUN R -e 'install.packages("cmdstanr", repos = c("https://stan-dev.r-universe.dev", "https://packagemanager.posit.co/cran/latest"))'

# Install the rest of the {renv} packages
RUN R -e 'renv::restore()'

RUN chown -R rstudio:rstudio /home/rstudio/${PROJECT}

# Install cmdstan
RUN mkdir /home/rstudio/.cmdstan
RUN R -e 'cmdstanr::install_cmdstan(dir = "/home/rstudio/.cmdstan", cpp_options = list("CXX" = "clang++"))'
RUN chown -R rstudio:rstudio /home/rstudio/.cmdstan

# Install Quarto
ARG QUARTO_VERSION="1.6.1"
RUN curl -L -o /tmp/quarto-linux-amd64.deb https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.deb && \
    dpkg -i /tmp/quarto-linux-amd64.deb || true && \
    apt-get install -fy && \
    rm /tmp/quarto-linux-amd64.deb

# Install LaTeX
USER rstudio
RUN Rscript -e 'tinytex::install_tinytex()'
ENV PATH="${PATH}:/home/rstudio/bin"
RUN tlmgr update --all --self
RUN tlmgr install \
    # dvisvgm stuff
    dvisvgm adjustbox collectbox currfile filemod gincltex standalone \
    fp pgf grfext libertine libertinust1math \
    # Quarto + Hikmah template stuff
    nowidow tocloft orcidlink abstract titling tabularray ninecolors \
    enumitem textcase titlesec footmisc caption pdflscape ulem multirow \
    wrapfig colortbl tabu threeparttable threeparttablex environ makecell \
    sidenotes marginnote changepage siunitx mathtools \
    setspace ragged2e fancyhdr pdftex preprint
USER root

# Add fonts
COPY ../docker/misc/fonts/noto-sans/*.ttf /usr/share/fonts/
COPY ../docker/misc/fonts/linux-libertine-o/*.otf /usr/share/fonts/
COPY ../docker/misc/fonts/libertinus-math/*.otf /usr/share/fonts/
RUN fc-cache -f -v


# ------------------------------------------------------------------------------
# STAGE 2: Use the pre-built image for the actual analysis + {targets} pipeline
# ------------------------------------------------------------------------------
FROM renv-base

# This .Rprofile contains commands that force RStudio server to load the
# analysis project by default
COPY --chown=rstudio:rstudio ../docker/misc/Rprofile.R /home/rstudio/.Rprofile

WORKDIR /home/rstudio/${PROJECT}
