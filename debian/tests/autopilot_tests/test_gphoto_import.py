'''Test import from libgphoto camera (with umockdev)'''

__author__ = 'Martin Pitt <martin.pitt@ubuntu.com>'
__copyright__ = 'GNU LGPL 2.1+'

import os
import tempfile
import os.path

from autopilot.testcase import AutopilotTestCase
from autopilot.matchers import Eventually
from testtools.matchers import Equals

mydir = os.path.dirname(__file__)


class T(AutopilotTestCase):
    def setUp(self):
        self.workdir = tempfile.mkdtemp()
        os.environ['HOME'] = self.workdir
        os.environ['XDG_RUNTIME_DIR'] = self.workdir
        os.environ['LC_ALL'] = 'C'

        super(T, self).setUp()
        self.app = self.launch_test_application(
            'umockdev-run', '-d', os.path.join(mydir, 'powershot.umockdev'),
            '-i', 'dev/bus/usb/001/011=' + os.path.join(mydir, 'powershot-import.ioctl'),
            '--', 'pantheon-photos', app_type='gtk')

        # we expect the welcome dialog, otherwise we don't have a pristine
        # config/data; wait until it's gone
        wd = self.app.wait_select_single('WelcomeDialog')
        self.mouse.click_object(wd)
        self.keyboard.press_and_release('Enter')
        self.assertThat(lambda: self.app.select_many('WelcomeDialog'),
                        Eventually(Equals([])))

    def tearDown(self):
        #shutil.rmtree(self.workdir)
        super(T, self).tearDown()

    def test_import(self):
        '''Import pictures from libgphoto camera'''

        # select SidebarTree; this is not introspectable, so we have to
        # navigate to "Cameras" blindly
        sidebar = self.app.select_single('SidebarTree')
        self.assertNotEqual(sidebar, None)
        self.assertThat(sidebar.visible, Eventually(Equals(True)))
        self.keyboard.press_and_release('Tab')
        self.keyboard.press_and_release('Tab')
        self.assertThat(sidebar.has_focus, Eventually(Equals(True)))

        # select first camera
        self.keyboard.press_and_release('Down')
        self.keyboard.press_and_release('Down')

        btn_import = self.app.select_single('GtkToolButton', label='Import _All')
        self.assertNotEqual(btn_import, None)
        self.assertThat(btn_import.visible, Eventually(Equals(True)))

        # properties window should show 2 photos
        basic_props = self.app.select_single('BasicProperties')
        self.assertNotEqual(basic_props.select_single('GtkLabel', label='2 Photos'), None)

        # do import
        self.mouse.click_object(btn_import)

        # wait for success dialog
        md = self.app.wait_select_single('GtkMessageDialog', visible=True)
        self.assertEqual(md.title, 'Import Complete')
        self.assertIn('2 photos successfully imported', md.text)

        # do the default action which is "Keep on camera"
        self.keyboard.press_and_release('Enter')
        self.assertThat(lambda: self.app.select_many('GtkMessageDialog'),
                        Eventually(Equals([])))

        page = self.app.select_single('LastImportPage')
        self.assertNotEqual(page, None)
        self.assertEqual(page.visible, True)

        # should have imported photos
        picture_dir = os.path.join(self.workdir, 'Pictures')
        date_dir = os.path.join(picture_dir, '2013', '08', '22')
        self.assertTrue(os.path.isdir(picture_dir), 'Created Pictures XDG dir')
        self.assertTrue(os.path.isdir(date_dir), 'Created by-date Pictures subfolder')
        self.assertTrue(os.path.exists(os.path.join(date_dir, 'IMG_0001.JPG')))
        self.assertTrue(os.path.exists(os.path.join(date_dir, 'IMG_0002.JPG')))