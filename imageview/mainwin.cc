/*
  Copyright (c) 2018 Brendan Fennell <bfennell@skynet.ie>

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.
*/

#include <cassert>
#include <cstdio>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

#include <QDebug>

#include "mainwin.h"

static void merge (uint8_t* last, uint8_t* curr)
{
    static int x = (((256*224)/8)/2);
    for (int i = x; i < (x + (((256*224)/8)/2)); i++) {
            last[i] = curr[i];
    }
    x = (x == 0) ? (((256*224)/8)/2) : 0;
}

MainWin::MainWin (int w, int h, QWidget* parent)
    : QLabel (parent), width (w), height (h), count(0)
{
    trans.rotate (-90);
    trans.scale (3,3);

    updateScreen ();

    connect (&timer, SIGNAL(timeout()), this, SLOT(onTimeout()), Qt::DirectConnection);
    timer.start (50);
}

void MainWin::updateScreen ()
{
    int fd;
    char buf[128];
    sprintf(buf, "image_%d.bin", count);

    if (-1 != (fd = open (buf, O_RDONLY))) {
        // printf("%s\n", buf);
        read (fd, image_cpy, (1024*7));
        ::close (fd);
        count++;
    }
    merge (image_bin, image_cpy);

    QImage image ((const unsigned char*)image_bin, width, height, QImage::Format_MonoLSB);

    setPixmap (QPixmap::fromImage(image).transformed(trans));
    update ();
}

void MainWin::closeEvent (QCloseEvent* event)
{
    event->accept ();
}

void MainWin::onTimeout ()
{
    updateScreen ();
}
