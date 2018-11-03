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

#ifndef __MAINWIN_H__
#define __MAINWIN_H__

#include <QApplication>
#include <QWidget>
#include <QLabel>
#include <QTransform>
#include <QKeyEvent>
#include <QVBoxLayout>
#include <QTimer>

#include <stdint.h>

class MainWin : public QLabel
{
    Q_OBJECT;
private slots:
    void onTimeout ();
public:
    MainWin (int width, int height, QWidget* parent = 0);
protected:
    void closeEvent (QCloseEvent* event);
private:
    void updateScreen ();

    int width;
    int height;
    QTransform trans;
    QTimer timer;
    int count;
    uint8_t image_bin[1024*8];
    uint8_t image_cpy[1024*8];
};

#endif // __MAINWIN_H__
