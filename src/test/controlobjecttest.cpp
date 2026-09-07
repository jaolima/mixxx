#include <gtest/gtest.h>

#include <QtDebug>
#include <memory>

#include "control/control.h"
#include "control/controlobject.h"
#include "test/mixxxtest.h"

namespace {

class ControlObjectTest : public MixxxTest {
  protected:
    void SetUp() override {
        ck1 = ConfigKey("[Channel1]", "co1");
        ck2 = ConfigKey("[Channel1]", "co2");
        co1 = std::make_unique<ControlObject>(ck1);
        co2 = std::make_unique<ControlObject>(ck2);
    }

    ConfigKey ck1, ck2;
    std::unique_ptr<ControlObject> co1;
    std::unique_ptr<ControlObject> co2;
};

TEST_F(ControlObjectTest, SetGet) {
    co1->set(1.0);
    EXPECT_DOUBLE_EQ(1.0, co1->get());
    co2->set(2.0);
    EXPECT_DOUBLE_EQ(2.0, co2->get());
}

TEST_F(ControlObjectTest, getControl) {
    EXPECT_EQ(ControlObject::getControl(ck1), co1.get());
    EXPECT_EQ(ControlObject::getControl(ck2), co2.get());
    co2.reset();
    EXPECT_EQ(ControlObject::getControl(ck2, ControlFlag::NoAssertIfMissing),
            (ControlObject*)nullptr);
}

TEST_F(ControlObjectTest, AliasRetrieval) {
    ConfigKey ck("[Microphone1]", "volume");
    ConfigKey ckAlias("[Microphone]", "volume");

    // Create the Control Object
    auto co = std::make_unique<ControlObject>(ck);

    // Insert the alias before it is going to be used
    co->addAlias(ckAlias);

    // Check if getControl on alias returns us the original ControlObject
    EXPECT_EQ(ControlObject::getControl(ckAlias), co.get());
}

TEST_F(ControlObjectTest, Persistence_NotPresent) {
    ConfigKey ck("[Test]", "persist");
    ASSERT_FALSE(m_pConfig->exists(ck));
    ControlObject co(ck, true, false, true, 3.0);
    // Should be initialized to default value with no valid value in config
    EXPECT_DOUBLE_EQ(3.0, co.get());
}

TEST_F(ControlObjectTest, Persistence_InvalidValue) {
    ConfigKey ck("[Test]", "persist");
    m_pConfig->set(ck, QString("NotANumber"));
    saveAndReloadConfig();

    ControlObject co(ck, true, false, true, 3.0);
    EXPECT_DOUBLE_EQ(3.0, co.get());
}

TEST_F(ControlObjectTest, Persistence_EmptyValue) {
    ConfigKey ck("[Test]", "persist");
    m_pConfig->set(ck, QString(""));
    saveAndReloadConfig();

    ControlObject co(ck, true, false, true, 3.0);
    EXPECT_DOUBLE_EQ(3.0, co.get());
}

TEST_F(ControlObjectTest, Persistence_ValidValue) {
    ConfigKey ck("[Test]", "persist");
    m_pConfig->set(ck, QString("5"));
    saveAndReloadConfig();

    ControlObject co(ck, true, false, true, 3.0);
    EXPECT_DOUBLE_EQ(5.0, co.get());
}

TEST_F(ControlObjectTest, Persistence_FlushWhileAlive) {
    ConfigKey ck("[Test]", "persist_flush");
    ControlObject co(ck, true, false, true, 3.0);
    co.set(7.0);

    // Until the sweep runs, the new value exists only in the control: a
    // persistent control writes to the configuration when it is destroyed, and
    // on Android that never happens.
    EXPECT_TRUE(m_pConfig->getValueString(ck).isEmpty());

    ControlDoublePrivate::saveAllPersistentValues();

    EXPECT_EQ(QStringLiteral("7"), m_pConfig->getValueString(ck));
    // The control is untouched by the sweep and stays usable.
    EXPECT_DOUBLE_EQ(7.0, co.get());
}

TEST_F(ControlObjectTest, Persistence_FlushIgnoresNonPersistent) {
    ConfigKey ck("[Test]", "no_persist_flush");
    ControlObject co(ck, true, false, false, 3.0);
    co.set(7.0);

    ControlDoublePrivate::saveAllPersistentValues();

    EXPECT_TRUE(m_pConfig->getValueString(ck).isEmpty());
}

TEST_F(ControlObjectTest, Persistence_FlushMatchesDestruction) {
    // The sweep must produce exactly what destroying the control would, or the
    // two paths drift and Android ends up with a different file than desktop.
    ConfigKey ckFlushed("[Test]", "persist_flushed");
    ConfigKey ckDestroyed("[Test]", "persist_destroyed");

    ControlObject flushed(ckFlushed, true, false, true, 3.0);
    flushed.set(0.125);
    {
        ControlObject destroyed(ckDestroyed, true, false, true, 3.0);
        destroyed.set(0.125);
    }

    ControlDoublePrivate::saveAllPersistentValues();

    EXPECT_EQ(m_pConfig->getValueString(ckDestroyed), m_pConfig->getValueString(ckFlushed));
}

} // namespace
